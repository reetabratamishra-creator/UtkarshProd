@RestResource(urlMapping='/thirdParty/payload/*')
global without sharing class ThirdPartyPayloadReceiver {
  private static final String DEFAULT_SOURCE = 'ThirdPartyApp';
  private static final String BLUEWAVES_SOURCE = 'Bluewaves';
  private static final String QUOTE_REPLY_SOURCE = 'Bluewaves_QuoteReply';
  private static final String CONTENT_TYPE_JSON = 'application/json';

  global class SuccessResponse {
    public String status;
    public String id;
  }

  global class ErrorResponse {
    public String status;
    public String message;
  }

  @HttpPost
  global static void receivePayload() {
    RestRequest request = RestContext.request;
    RestResponse response = RestContext.response;
    Webhook_Debug_Log__c debugLog = buildDebugLog(request);

    try {
      String rawBody = request.requestBody == null
        ? ''
        : request.requestBody.toString();

      // #region agent log
      debugLog.Body_Length__c = rawBody == null ? 0 : rawBody.length();
      insertDebugLog(debugLog, 'H4', 'request_received');
      // #endregion

      if (String.isBlank(rawBody)) {
        // #region agent log
        finalizeDebugLog(debugLog, 'EMPTY_BODY', null, 'Request body is required.');
        // #endregion
        writeError(response, 400, 'Request body is required.');
        return;
      }

      Incoming_Payload__c record = new Incoming_Payload__c();
      record.Raw_Payload__c = rawBody;
      record.Received_At__c = System.now();
      record.Source__c = resolveSource(request, rawBody);
      applyOptionalFields(record, rawBody);
      insert record;

      // #region agent log
      finalizeDebugLog(debugLog, 'SUCCESS', record.Id, null);
      // #endregion

      SuccessResponse successResponse = new SuccessResponse();
      successResponse.status = 'success';
      successResponse.id = record.Id;

      response.statusCode = 200;
      response.addHeader('Content-Type', CONTENT_TYPE_JSON);
      response.responseBody = Blob.valueOf(JSON.serialize(successResponse));
    } catch (Exception ex) {
      // #region agent log
      finalizeDebugLog(debugLog, 'EXCEPTION', null, ex.getMessage());
      // #endregion
      writeError(response, 400, ex.getMessage());
    }
  }

  private static Webhook_Debug_Log__c buildDebugLog(RestRequest request) {
    Webhook_Debug_Log__c debugLog = new Webhook_Debug_Log__c();
    debugLog.Received_At__c = System.now();

    if (request == null) {
      debugLog.Request_Uri__c = 'null-request';
      return debugLog;
    }

    debugLog.Request_Uri__c = request.requestURI;
    debugLog.Has_Auth_Header__c = hasAuthorizationHeader(request);
    debugLog.X_Source__c = request.headers == null
      ? null
      : request.headers.get('X-Source');
    return debugLog;
  }

  private static Boolean hasAuthorizationHeader(RestRequest request) {
    if (request == null || request.headers == null) {
      return false;
    }

    for (String headerName : request.headers.keySet()) {
      if (headerName != null && headerName.equalsIgnoreCase('Authorization')) {
        return String.isNotBlank(request.headers.get(headerName));
      }
    }
    return false;
  }

  private static void insertDebugLog(
    Webhook_Debug_Log__c debugLog,
    String hypothesisId,
    String stage
  ) {
    try {
      insert debugLog;
      System.debug(
        LoggingLevel.INFO,
        'ThirdPartyPayloadReceiver debug [' +
          hypothesisId +
          '][' +
          stage +
          '] uri=' +
          debugLog.Request_Uri__c +
          ' auth=' +
          debugLog.Has_Auth_Header__c +
          ' bodyLen=' +
          debugLog.Body_Length__c
      );
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'ThirdPartyPayloadReceiver debug log insert failed: ' + ex.getMessage()
      );
    }
  }

  private static void finalizeDebugLog(
    Webhook_Debug_Log__c debugLog,
    String outcome,
    Id incomingPayloadId,
    String errorMessage
  ) {
    if (debugLog == null || debugLog.Id == null) {
      return;
    }

    debugLog.Outcome__c = outcome;
    debugLog.Incoming_Payload_Id__c = incomingPayloadId == null
      ? null
      : String.valueOf(incomingPayloadId);
    debugLog.Error_Message__c = errorMessage;

    try {
      update debugLog;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'ThirdPartyPayloadReceiver debug log update failed: ' + ex.getMessage()
      );
    }
  }

  private static String resolveSource(RestRequest request, String rawBody) {
    if (request != null && request.headers != null) {
      String headerSource = request.headers.get('X-Source');
      if (String.isNotBlank(headerSource)) {
        return headerSource.trim();
      }
    }

    Map<String, Object> payload = parsePayload(rawBody);
    String bodySource = extractString(payload, 'source', null, null, null);
    if (String.isNotBlank(bodySource)) {
      return bodySource;
    }

    if (payload != null && isQuoteReplyPayload(payload)) {
      return QUOTE_REPLY_SOURCE;
    }

    return DEFAULT_SOURCE;
  }

  private static void applyOptionalFields(
    Incoming_Payload__c record,
    String rawBody
  ) {
    Map<String, Object> payload = parsePayload(rawBody);
    if (payload == null) {
      return;
    }

    record.Message_Id__c = extractString(
      payload,
      'messageId',
      'message_id',
      'id',
      'biz_opaque_callback_data'
    );
    record.Status__c = extractQuoteReplyStatus(payload);
    if (String.isBlank(record.Status__c)) {
      record.Status__c = extractString(
        payload,
        'status',
        'deliveryStatus',
        'delivery_status',
        null
      );
    }

    if (
      isQuoteReplyPayload(payload) &&
      (String.isBlank(record.Source__c) ||
      record.Source__c == DEFAULT_SOURCE)
    ) {
      record.Source__c = QUOTE_REPLY_SOURCE;
    }
  }

  private static Boolean isQuoteReplyPayload(Map<String, Object> payload) {
    if (payload == null || payload.isEmpty()) {
      return false;
    }

    String replyStatus = extractQuoteReplyStatus(payload);
    if (String.isNotBlank(replyStatus)) {
      return true;
    }

    String serialized = JSON.serialize(payload).toLowerCase();
    return serialized.contains('quotation_manual_trigger') ||
      serialized.contains('biz_opaque_callback_data') ||
      serialized.contains('quick_reply') ||
      serialized.contains('"button"');
  }

  private static String extractQuoteReplyStatus(Map<String, Object> payload) {
    String directStatus = extractString(
      payload,
      'status',
      'reply',
      'answer',
      'response',
      'button_reply',
      'payload'
    );
    if (isYesNoReply(directStatus)) {
      return directStatus;
    }

    String nestedStatus = extractNestedButtonReply(payload);
    if (String.isNotBlank(nestedStatus)) {
      return nestedStatus;
    }

    return null;
  }

  private static String extractNestedButtonReply(Map<String, Object> payload) {
    Object messagesObject = payload.get('messages');
    if (!(messagesObject instanceof List<Object>)) {
      messagesObject = payload.get('message');
    }
    if (!(messagesObject instanceof List<Object>)) {
      if (messagesObject instanceof Map<String, Object>) {
        return extractButtonReplyFromMessage((Map<String, Object>) messagesObject);
      }
      return null;
    }

    for (Object messageObject : (List<Object>) messagesObject) {
      if (!(messageObject instanceof Map<String, Object>)) {
        continue;
      }
      String reply = extractButtonReplyFromMessage((Map<String, Object>) messageObject);
      if (String.isNotBlank(reply)) {
        return reply;
      }
    }

    return null;
  }

  private static String extractButtonReplyFromMessage(
    Map<String, Object> messageMap
  ) {
    if (messageMap == null) {
      return null;
    }

    Map<String, Object> buttonMap = messageMap.get('button') instanceof Map<String, Object>
      ? (Map<String, Object>) messageMap.get('button')
      : null;
    if (buttonMap != null) {
      String payloadValue = extractString(buttonMap, 'payload', 'text', 'title', null);
      if (isYesNoReply(payloadValue)) {
        return payloadValue;
      }
    }

    Map<String, Object> interactiveMap = messageMap.get('interactive') instanceof Map<String, Object>
      ? (Map<String, Object>) messageMap.get('interactive')
      : null;
    if (interactiveMap == null) {
      return null;
    }

    Map<String, Object> buttonReplyMap = interactiveMap.get('button_reply') instanceof Map<String, Object>
      ? (Map<String, Object>) interactiveMap.get('button_reply')
      : null;
    if (buttonReplyMap == null) {
      return null;
    }

    return extractString(buttonReplyMap, 'id', 'title', 'payload', null);
  }

  private static Boolean isYesNoReply(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    String normalized = value.trim().toLowerCase();
    return normalized == 'yes' || normalized == 'no';
  }

  private static Map<String, Object> parsePayload(String rawBody) {
    if (String.isBlank(rawBody)) {
      return null;
    }

    try {
      Object parsed = JSON.deserializeUntyped(rawBody);
      return parsed instanceof Map<String, Object>
        ? (Map<String, Object>) parsed
        : null;
    } catch (Exception ex) {
      return null;
    }
  }

  private static String extractString(
    Map<String, Object> payload,
    String firstKey,
    String secondKey,
    String thirdKey,
    String fourthKey,
    String fifthKey,
    String sixthKey
  ) {
    if (payload == null) {
      return null;
    }

    List<String> keys = new List<String>{
      firstKey,
      secondKey,
      thirdKey,
      fourthKey,
      fifthKey,
      sixthKey
    };
    for (String key : keys) {
      if (String.isBlank(key) || !payload.containsKey(key)) {
        continue;
      }
      Object value = payload.get(key);
      if (value != null && String.isNotBlank(String.valueOf(value))) {
        return String.valueOf(value).trim();
      }
    }

    return null;
  }

  private static String extractString(
    Map<String, Object> payload,
    String firstKey,
    String secondKey,
    String thirdKey,
    String fourthKey
  ) {
    return extractString(payload, firstKey, secondKey, thirdKey, fourthKey, null, null);
  }

  private static void writeError(
    RestResponse response,
    Integer statusCode,
    String message
  ) {
    ErrorResponse errorResponse = new ErrorResponse();
    errorResponse.status = 'error';
    errorResponse.message = message;

    response.statusCode = statusCode;
    response.addHeader('Content-Type', CONTENT_TYPE_JSON);
    response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
  }
}