/**
 * @description   Builds direct RCS API payloads for campaign and messaging sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_RcsDirectPayloadBuilder {
  private static final String TEMPLATES_PATH = '/api/v1/rcs/getTemplate';

  @TestVisible
  private static Map<String, Map<String, Object>> templateByName;

  public static void cacheTemplates(List<Object> templateRows) {
    templateByName = new Map<String, Map<String, Object>>();
    if (templateRows == null) {
      return;
    }

    for (Object templateObject : templateRows) {
      Map<String, Object> templateMap = (Map<String, Object>) templateObject;
      String templateName = (String) templateMap.get('TemplateName');
      if (String.isNotBlank(templateName)) {
        templateByName.put(normalizeName(templateName), templateMap);
      }
    }
  }

  /**
   * Builds RCS bodyData for Journey node payloads using named template parameters
   * (e.g. Department_name_1, Product_Brief), not WhatsApp-style {{1}} placeholders.
   */
  public static Map<String, Object> buildNamedBodyDataForJourney(
    BWM_Messaging_Settings__mdt settings,
    String templateName,
    SObject record,
    Map<String, Object> fallbackPlaceholderToParamName
  ) {
    ensureTemplateCacheLoaded(settings);

    List<String> requiredParamNames = extractRequiredParamNames(templateName);
    if (requiredParamNames.isEmpty() && fallbackPlaceholderToParamName != null) {
      requiredParamNames = extractParamNamesFromPlaceholderMap(
        fallbackPlaceholderToParamName
      );
    }

    if (requiredParamNames.isEmpty()) {
      return new Map<String, Object>();
    }

    Map<String, Object> namedParams = buildParams(
      settings,
      templateName,
      record,
      requiredParamNames
    );
    return usePositionalKeysWhenTemplateHasNoVariableNames(
      requiredParamNames,
      namedParams
    );
  }

  /**
   * Prospect_enq_gen and DEALER_Enq_gen only carry Rudra and Bhagyashree numbers.
   * Bluewave stores those as {{1}} and {{2}} with no variable name, so named keys
   * are rejected.
   */
  private static Map<String, Object> usePositionalKeysWhenTemplateHasNoVariableNames(
    List<String> requiredParamNames,
    Map<String, Object> namedParams
  ) {
    if (namedParams == null || namedParams.isEmpty() || requiredParamNames == null) {
      return namedParams;
    }

    for (String paramName : requiredParamNames) {
      String normalized = paramName == null ? '' : paramName.trim().toLowerCase();
      if (normalized != 'rudra_number' && normalized != 'bhagyashree_number') {
        return namedParams;
      }
    }

    Map<String, Object> positional = new Map<String, Object>();
    Integer index = 1;
    for (String paramName : requiredParamNames) {
      positional.put(
        '{{' + String.valueOf(index) + '}}',
        namedParams.get(paramName)
      );
      index++;
    }
    return positional;
  }

  public static String buildPayload(
    BWM_Messaging_Settings__mdt settings,
    String templateName,
    SObject record,
    String phoneNumber
  ) {
    ensureTemplateCacheLoaded(settings);

    List<String> requiredParamNames = extractRequiredParamNames(templateName);
    Map<String, Object> params = buildParams(
      settings,
      templateName,
      record,
      requiredParamNames
    );
    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByChannelTemplate(
        'RCS',
        templateName,
        record
      );
    Map<String, Object> autoBody = BWM_MessagePayloadBuilder.rcsBodyForCampaign(
      settings,
      mapping,
      record
    );
    if (autoBody != null && !autoBody.isEmpty()) {
      params = autoBody;
    }

    Map<String, Object> payload = new Map<String, Object>{
      'channel' => BWM_MessagingConstants.CHANNEL_RCS,
      'to' => new List<String>{ phoneNumber },
      'from' => settings.RCS_From__c,
      'content' => new Map<String, Object>{
        'data' => new Map<String, Object>{ 'templatename' => templateName.trim() },
        'params' => params
      }
    };

    return BWM_JourneyDefinitionService.applyScheduledDateTime(
      JSON.serialize(payload),
      BWM_CampaignScheduleContext.scheduledDateTime
    );
  }

  private static void ensureTemplateCacheLoaded(
    BWM_Messaging_Settings__mdt settings
  ) {
    if (templateByName != null && !templateByName.isEmpty()) {
      return;
    }

    if (settings == null || String.isBlank(settings.RCS_From__c)) {
      return;
    }

    if (Test.isRunningTest()) {
      return;
    }

    String endpoint =
      BWM_MessagingConstants.NAMED_CREDENTIAL +
      TEMPLATES_PATH +
      '?botid=' +
      EncodingUtil.urlEncode(settings.RCS_From__c, 'UTF-8');

    HttpRequest request = new HttpRequest();
    request.setEndpoint(endpoint);
    request.setMethod('GET');
    request.setHeader('Content-Type', 'application/json');
    request.setHeader(
      String.isNotBlank(settings.API_Key_Header__c)
        ? settings.API_Key_Header__c
        : 'Authorization',
      'Bearer ' + settings.API_Bearer_Token__c
    );
    request.setTimeout(120000);

    HttpResponse response = new Http().send(request);
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      return;
    }

    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
      response.getBody()
    );
    cacheTemplates((List<Object>) responseBody.get('data'));
  }

  private static List<String> extractParamNamesFromPlaceholderMap(
    Map<String, Object> placeholderToParamName
  ) {
    List<String> paramNames = new List<String>();
    if (placeholderToParamName == null || placeholderToParamName.isEmpty()) {
      return paramNames;
    }

    for (Integer index = 1; index <= 20; index++) {
      String placeholder = '{{' + String.valueOf(index) + '}}';
      if (!placeholderToParamName.containsKey(placeholder)) {
        continue;
      }
      Object rawValue = placeholderToParamName.get(placeholder);
      String paramName = rawValue == null ? '' : String.valueOf(rawValue).trim();
      if (String.isNotBlank(paramName)) {
        paramNames.add(paramName);
      }
    }

    return paramNames;
  }

  private static List<String> extractRequiredParamNames(String templateName) {
    List<String> paramNames = new List<String>();
    if (String.isBlank(templateName) || templateByName == null) {
      return paramNames;
    }

    Map<String, Object> templateMap = templateByName.get(normalizeName(templateName));
    if (templateMap == null) {
      return paramNames;
    }

    Map<String, Object> component = (Map<String, Object>) templateMap.get('Component');
    if (component == null) {
      return paramNames;
    }

    List<Object> cards = (List<Object>) component.get('Cards');
    if (cards == null) {
      return paramNames;
    }

    Map<Integer, String> orderedParams = new Map<Integer, String>();
    for (Object cardObject : cards) {
      Map<String, Object> card = (Map<String, Object>) cardObject;
      collectVariableMappings(card.get('DescVariables'), orderedParams);
      collectVariableMappings(card.get('TitleVariables'), orderedParams);
    }

    List<Integer> indexes = new List<Integer>(orderedParams.keySet());
    indexes.sort();
    for (Integer index : indexes) {
      paramNames.add(orderedParams.get(index));
    }

    return paramNames;
  }

  private static void collectVariableMappings(
    Object variableRows,
    Map<Integer, String> orderedParams
  ) {
    if (!(variableRows instanceof List<Object>)) {
      return;
    }

    for (Object variableObject : (List<Object>) variableRows) {
      if (!(variableObject instanceof Map<String, Object>)) {
        continue;
      }

      Map<String, Object> variableMap = (Map<String, Object>) variableObject;
      for (String placeholder : variableMap.keySet()) {
        Integer index = parsePlaceholderIndex(placeholder);
        String paramName = String.valueOf(variableMap.get(placeholder));
        if (index != null && String.isNotBlank(paramName)) {
          orderedParams.put(index, paramName.trim());
        }
      }
    }
  }

  private static Integer parsePlaceholderIndex(String placeholder) {
    if (String.isBlank(placeholder)) {
      return null;
    }

    Matcher matcher = Pattern.compile('\\{\\{(\\d+)\\}\\}').matcher(placeholder.trim());
    if (!matcher.find()) {
      return null;
    }

    return Integer.valueOf(matcher.group(1));
  }

  private static Map<String, Object> buildParams(
    BWM_Messaging_Settings__mdt settings,
    String templateName,
    SObject record,
    List<String> requiredParamNames
  ) {
    Map<String, Object> params = new Map<String, Object>();

    for (String paramName : requiredParamNames) {
      params.put(
        paramName,
        rcsSafeValue(
          resolveParamByName(settings, record, paramName),
          paramName
        )
      );
    }

    return params;
  }

  private static String resolveParamByName(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    String paramName
  ) {
    if (String.isBlank(paramName)) {
      return '';
    }

    String normalized = paramName.trim().toLowerCase();
    String departmentName = resolveDepartmentName(record);
    String ownerName = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Name');
    String ownerPhone = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Phone');
    String ownerEmail = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Email');
    String productBrief = resolveProductBrief(record);

    if (normalized == 'rudra_number') {
      return resolveCorporateSupportPhone(settings, record, 1);
    }
    if (normalized == 'bhagyashree_number') {
      return resolveCorporateSupportPhone(settings, record, 2);
    }
    if (
      normalized == 'department_name_1' ||
      normalized == 'department_name_2' ||
      normalized == 'department_name_3'
    ) {
      return departmentName;
    }
    if (normalized == 'product_brief' || normalized == 'brief') {
      return productBrief;
    }
    if (normalized == 'lead_owner_name' || normalized == 'lead_owner') {
      return ownerName;
    }
    if (normalized == 'lead_owner_phone') {
      return ownerPhone;
    }
    if (normalized == 'lead_owner_email') {
      return ownerEmail;
    }
    if (
      normalized == 'opportunity_owner_name' ||
      normalized == 'opportunity_owner'
    ) {
      return ownerName;
    }
    if (
      normalized == 'opportunity_owner_phone' ||
      normalized == 'opportunity_owner_number'
    ) {
      return ownerPhone;
    }
    if (normalized == 'opportunity_owner_email') {
      return ownerEmail;
    }
    if (normalized == 'department_crm_name') {
      return BWM_FieldValueResolver.resolveRecord(
        record,
        BWM_MessagingConstants.FIELD_CRM_USER_NAME
      );
    }
    if (
      normalized == 'department_crm_phone' ||
      normalized == 'department_crm_number'
    ) {
      return BWM_FieldValueResolver.resolveRecord(
        record,
        BWM_MessagingConstants.FIELD_CRM_USER_PHONE
      );
    }
    if (normalized == 'department_crm_email') {
      return BWM_FieldValueResolver.resolveRecord(
        record,
        BWM_MessagingConstants.FIELD_CRM_USER_EMAIL
      );
    }
    if (normalized == 'owner') {
      return ownerName;
    }
    if (normalized == 'email') {
      String recordEmail = BWM_FieldValueResolver.resolveRecord(record, 'Email');
      return String.isNotBlank(recordEmail) ? recordEmail : ownerEmail;
    }
    if (normalized == 'number') {
      return ownerPhone;
    }

    return BWM_FieldValueResolver.resolveRecord(record, paramName);
  }

  private static String resolveDepartmentName(SObject record) {
    String departmentName = BWM_FieldValueResolver.resolveDepartmentName(record);
    if (String.isBlank(departmentName)) {
      departmentName = BWM_FieldValueResolver.resolveRecord(
        record,
        'Department_Name__c'
      );
    }
    return String.isNotBlank(departmentName) ? departmentName.trim() : 'NA';
  }

  private static String resolveProductBrief(SObject record) {
    String productBrief = BWM_FieldValueResolver.resolveRecord(
      record,
      BWM_MessagingConstants.FIELD_WHATSAPP_PRODUCT_BRIEF
    );
    if (String.isBlank(productBrief)) {
      productBrief = BWM_FieldValueResolver.resolveRecord(
        record,
        'Product_Category__c'
      );
    }
    if (String.isBlank(productBrief) && record != null) {
      Object nameValue = record.get('Name');
      productBrief = nameValue == null ? null : String.valueOf(nameValue);
    }
    return String.isNotBlank(productBrief) ? productBrief.trim() : 'NA';
  }

  private static String resolveCorporateSupportPhone(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    Integer contactNumber
  ) {
    String fieldToken = contactNumber == 1
      ? BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1
      : BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_2;
    String phone = BWM_FieldValueResolver.resolveRecord(record, fieldToken);

    if (String.isBlank(phone) && settings != null) {
      String settingsPhone = contactNumber == 1
        ? settings.Corporate_Support_Contact_1_Phone__c
        : settings.Corporate_Support_Contact_2_Phone__c;
      if (String.isNotBlank(settingsPhone)) {
        phone = settingsPhone.replaceAll('[^0-9]', '');
        if (phone.length() >= 10) {
          phone = phone.substring(phone.length() - 10);
        }
      }
    }

    return phone;
  }

  private static String rcsSafeValue(String rawValue, String paramName) {
    if (String.isNotBlank(rawValue)) {
      String paramToken = paramName == null ? '' : paramName.trim();
      if (rawValue.trim().equalsIgnoreCase(paramToken)) {
        return ' ';
      }
      return BWM_MessagePayloadBuilder.blankChannelSlot(rawValue);
    }
    return isPhoneParam(paramName) ? ' ' : 'NA';
  }

  private static Boolean isPhoneParam(String paramName) {
    if (String.isBlank(paramName)) {
      return false;
    }
    String normalized = paramName.trim().toLowerCase();
    return normalized.contains('phone') ||
      normalized.contains('number') ||
      normalized.endsWith('_number');
  }

  private static String normalizeName(String value) {
    return String.isBlank(value) ? '' : value.trim().toLowerCase();
  }

  @TestVisible
  static void clearCache() {
    templateByName = null;
  }
}