/**
 * @description   Builds direct SMS API payloads for campaign and messaging sends.
 *                Owner contact phone slots use User Mobile → Phone only; blank stays
 *                blank (never corporate / WhatsApp_From / NA).
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_SmsDirectPayloadBuilder {
  private static final Pattern SMS_PLACEHOLDER_PATTERN = Pattern.compile(
    '\\{#([^#]+)#\\}'
  );

  @TestVisible
  private static Map<String, Map<String, Object>> templateByName;

  public static void cacheTemplates(List<Object> templateRows) {
    templateByName = new Map<String, Map<String, Object>>();
    if (templateRows == null) {
      return;
    }

    for (Object templateObject : templateRows) {
      Map<String, Object> templateMap = (Map<String, Object>) templateObject;
      String templateName = readTemplateName(templateMap);
      if (String.isNotBlank(templateName)) {
        templateByName.put(normalizeName(templateName), templateMap);
      }
    }
  }

  public static String buildPayload(
    BWM_Messaging_Settings__mdt settings,
    String templateName,
    SObject record,
    String phoneNumber
  ) {
    ensureTemplateCacheLoaded(settings);

    String normalizedTemplateName = templateName == null ? '' : templateName.trim();
    if (String.isBlank(normalizedTemplateName)) {
      throw new BWM_MessagingException('SMS template name is required.');
    }

    Map<String, Object> templateMap = templateByName == null
      ? null
      : templateByName.get(normalizeName(normalizedTemplateName));
    if (templateMap == null) {
      throw new BWM_MessagingException(
        'SMS template not found: ' + normalizedTemplateName
      );
    }

    String dltTemplateId = readDltTemplateId(templateMap);
    String templateText = readTemplateText(templateMap);
    if (String.isBlank(dltTemplateId) || String.isBlank(templateText)) {
      throw new BWM_MessagingException(
        'SMS template metadata is incomplete for: ' + normalizedTemplateName
      );
    }

    BWM_Template_Mapping__mdt mapping =
      BWM_JourneyDefinitionService.findMappingByChannelTemplate(
        'SMS',
        normalizedTemplateName,
        record
      );
    Map<String, Object> autoMappings = BWM_MessagePayloadBuilder.smsMappingsForCampaign(
      mapping,
      record
    );
    Map<String, Object> variableMappings;
    if (autoMappings.isEmpty()) {
      String journeyName = BWM_JourneyDefinitionService.findJourneyNameBySmsTemplateName(
        normalizedTemplateName
      );
      Map<String, Object> journeyMappings = resolveJourneyVariableMappings(
        settings,
        record,
        mapping,
        journeyName
      );
      variableMappings = finalizeVariableMappings(
        settings,
        record,
        templateMap,
        journeyMappings
      );
    } else {
      variableMappings = new Map<String, Object>();
      for (String key : autoMappings.keySet()) {
        variableMappings.put(
          key,
          normalizeSmsVariableValue(
            autoMappings.get(key) == null ? '' : String.valueOf(autoMappings.get(key)),
            settings
          )
        );
      }
    }

    String senderId = String.isNotBlank(settings == null ? null : settings.SMS_From__c)
      ? settings.SMS_From__c.trim()
      : 'UTKRSI';

    Map<String, Object> payload = new Map<String, Object>{
      'channel' => BWM_MessagingConstants.CHANNEL_SMS,
      'to' => new List<String>{ phoneNumber },
      'from' => senderId,
      'content' => new Map<String, Object>{
        'data' => new Map<String, Object>{
          'dlttemplateid' => dltTemplateId,
          'text' => templateText,
          'peid' => resolvePeid(settings),
          'chainvalue' => resolveChainValue(settings)
        },
        'params' => toVarParams(variableMappings, extractPlaceholderTypes(templateMap))
      }
    };

    return BWM_JourneyDefinitionService.applyScheduledDateTime(
      JSON.serialize(payload),
      BWM_CampaignScheduleContext.scheduledDateTime
    );
  }

  private static Map<String, Object> toVarParams(
    Map<String, Object> variableMappings,
    List<String> placeholderTypes
  ) {
    Map<String, Object> params = new Map<String, Object>();
    if (variableMappings == null || variableMappings.isEmpty()) {
      return params;
    }

    Map<String, Integer> typeOccurrence = new Map<String, Integer>();
    Integer placeholderCount = placeholderTypes == null ? 0 : placeholderTypes.size();

    for (String mappingKey : variableMappings.keySet()) {
      Object value = variableMappings.get(mappingKey);
      if (value == null) {
        continue;
      }

      String paramKey = String.isNotBlank(mappingKey) && mappingKey.startsWith('var')
        ? mappingKey
        : 'var' + mappingKey;
      params.put(paramKey, value);

      Integer placeholderIndex = parsePlaceholderIndex(mappingKey);
      if (
        placeholderIndex == null ||
        placeholderIndex < 0 ||
        placeholderIndex >= placeholderCount
      ) {
        continue;
      }

      String placeholderType = placeholderTypes[placeholderIndex];
      if (String.isBlank(placeholderType)) {
        continue;
      }

      Integer occurrence = typeOccurrence.containsKey(placeholderType)
        ? typeOccurrence.get(placeholderType) + 1
        : 1;
      typeOccurrence.put(placeholderType, occurrence);

      String typeKey = occurrence == 1
        ? placeholderType
        : placeholderType + String.valueOf(occurrence);
      params.put(typeKey, value);
    }

    return params;
  }

  private static Integer parsePlaceholderIndex(String mappingKey) {
    if (String.isBlank(mappingKey)) {
      return null;
    }

    String normalizedKey = mappingKey.trim();
    if (normalizedKey.startsWith('var')) {
      normalizedKey = normalizedKey.substring(3);
    }

    if (!Pattern.matches('^\\d+$', normalizedKey)) {
      return null;
    }

    return Integer.valueOf(normalizedKey) - 1;
  }

  private static String resolvePeid(BWM_Messaging_Settings__mdt settings) {
    return DEFAULT_SMS_PEID;
  }

  private static String resolveChainValue(BWM_Messaging_Settings__mdt settings) {
    return DEFAULT_SMS_CHAIN_VALUE;
  }

  private static final String DEFAULT_SMS_PEID = '1701159714233362956';
  private static final String DEFAULT_SMS_CHAIN_VALUE =
    '1701159714233362956,140200000077';

  private static Map<String, Object> resolveJourneyVariableMappings(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    BWM_Template_Mapping__mdt mapping,
    String journeyName
  ) {
    Map<String, Object> variableMappings = new Map<String, Object>();
    if (String.isBlank(journeyName)) {
      return variableMappings;
    }

    Map<String, Object> templateMappings =
      BWM_JourneyDefinitionService.getSmsVariableMappingsTemplate(journeyName);
    if (templateMappings.isEmpty()) {
      return variableMappings;
    }

    Map<String, Object> resolvedMappings = (Map<String, Object>) BWM_JourneyPayloadResolver.resolveDataPayload(
      record,
      templateMappings,
      mapping
    );
    for (String key : resolvedMappings.keySet()) {
      Object rawValue = resolvedMappings.get(key);
      variableMappings.put(
        key,
        rawValue == null ? '' : String.valueOf(rawValue).trim()
      );
    }
    return variableMappings;
  }

  private static Map<String, Object> finalizeVariableMappings(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    Map<String, Object> templateMap,
    Map<String, Object> journeyMappings
  ) {
    Map<String, Object> fallbackMappings = buildVariableMappingsFromTemplateText(
      settings,
      record,
      templateMap
    );
    List<String> placeholderTypes = extractPlaceholderTypes(templateMap);
    if (placeholderTypes.isEmpty()) {
      return normalizeVariableMappingValues(
        settings,
        mergeVariableMappings(journeyMappings, fallbackMappings)
      );
    }

    String templateText = readTemplateText(templateMap);
    Map<String, Object> finalizedMappings = new Map<String, Object>();
    for (Integer index = 0; index < placeholderTypes.size(); index++) {
      String key = String.valueOf(index + 1);
      String value = readMappingValue(journeyMappings, key);
      if (String.isBlank(value)) {
        value = readMappingValue(fallbackMappings, key);
      }
      Boolean phoneSlot = isOwnerPhonePlaceholderSlot(
        placeholderTypes[index],
        templateText,
        index
      );
      if (phoneSlot) {
        value = BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(record, value);
      }
      value = normalizeSmsVariableValue(value, settings);
      finalizedMappings.put(key, valueOrEmptySlot(value, phoneSlot));
    }
    return finalizedMappings;
  }

  private static Map<String, Object> mergeVariableMappings(
    Map<String, Object> primaryMappings,
    Map<String, Object> fallbackMappings
  ) {
    Map<String, Object> mergedMappings = new Map<String, Object>();
    if (fallbackMappings != null) {
      mergedMappings.putAll(fallbackMappings);
    }
    if (primaryMappings == null) {
      return mergedMappings;
    }

    for (String key : primaryMappings.keySet()) {
      String primaryValue = readMappingValue(primaryMappings, key);
      if (String.isNotBlank(primaryValue)) {
        mergedMappings.put(key, primaryValue);
        continue;
      }
      // Intentional blank from journey (e.g. Owner.Phone empty) must clear any
      // digit fallback — never keep corporate / WhatsApp_From in that slot.
      String fallbackValue = readMappingValue(mergedMappings, key);
      if (String.isBlank(fallbackValue) || looksLikePhoneDigits(fallbackValue)) {
        mergedMappings.put(key, '');
      }
    }
    return mergedMappings;
  }

  private static Map<String, Object> normalizeVariableMappingValues(
    BWM_Messaging_Settings__mdt settings,
    Map<String, Object> variableMappings
  ) {
    Map<String, Object> normalizedMappings = new Map<String, Object>();
    if (variableMappings == null) {
      return normalizedMappings;
    }

    for (String key : variableMappings.keySet()) {
      String rawValue = readMappingValue(variableMappings, key);
      String value = normalizeSmsVariableValue(rawValue, settings);
      // Preserve intentional blanks (owner phone empty). Do not coerce digit
      // slots that were cleared from corporate fallback back into NA.
      if (String.isBlank(value)) {
        normalizedMappings.put(key, ' ');
      } else {
        normalizedMappings.put(key, value);
      }
    }
    return normalizedMappings;
  }

  private static String readMappingValue(
    Map<String, Object> variableMappings,
    String key
  ) {
    if (variableMappings == null || !variableMappings.containsKey(key)) {
      return '';
    }
    Object rawValue = variableMappings.get(key);
    return rawValue == null ? '' : String.valueOf(rawValue).trim();
  }

  private static String normalizeSmsVariableValue(
    String value,
    BWM_Messaging_Settings__mdt settings
  ) {
    if (String.isBlank(value)) {
      return value;
    }

    String trimmed = value.trim();
    String digitsOnly = trimmed.replaceAll('[^0-9]', '');
    if (digitsOnly.length() < 10) {
      return trimmed;
    }

    String formattedPhone = formatSmsPhoneValue(trimmed, settings);
    if (String.isBlank(formattedPhone)) {
      return toLocalMobileDigits(digitsOnly, settings);
    }
    return toLocalMobileDigits(formattedPhone, settings);
  }

  private static String toLocalMobileDigits(
    String digits,
    BWM_Messaging_Settings__mdt settings
  ) {
    if (String.isBlank(digits)) {
      return digits;
    }

    String countryCode = String.isBlank(
        settings == null ? null : settings.Default_Country_Code__c
      )
      ? '91'
      : settings.Default_Country_Code__c.replaceAll('[^0-9]', '');
    if (digits.startsWith(countryCode) && digits.length() == countryCode.length() + 10) {
      return digits.substring(countryCode.length());
    }
    if (digits.length() == 10) {
      return digits;
    }
    return digits;
  }

  private static void ensureTemplateCacheLoaded(
    BWM_Messaging_Settings__mdt settings
  ) {
    if (templateByName != null && !templateByName.isEmpty()) {
      return;
    }

    if (settings == null || Test.isRunningTest()) {
      return;
    }

    HttpResponse response = BWM_SmsTemplateService.fetchTemplatesResponse(settings);
    if (response == null || response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      return;
    }

    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
      response.getBody()
    );
    cacheTemplates((List<Object>) responseBody.get('data'));
  }

  private static Map<String, Object> buildVariableMappingsFromTemplateText(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    Map<String, Object> templateMap
  ) {
    Map<String, Object> variableMappings = new Map<String, Object>();
    List<String> placeholderTypes = extractPlaceholderTypes(templateMap);
    if (placeholderTypes.isEmpty()) {
      return variableMappings;
    }

    String templateText = readTemplateText(templateMap);
    List<String> values = buildVariableValues(
      settings,
      record,
      templateMap,
      placeholderTypes
    );
    for (Integer index = 0; index < placeholderTypes.size(); index++) {
      String value = index < values.size() ? values[index] : '';
      Boolean phoneSlot = isOwnerPhonePlaceholderSlot(
        placeholderTypes[index],
        templateText,
        index
      );
      variableMappings.put(
        String.valueOf(index + 1),
        valueOrEmptySlot(value, phoneSlot)
      );
    }

    return variableMappings;
  }

  /**
   * @description Phone slots use a space when empty so the handset stays empty.
   *              Other empty slots use NA.
   */
  private static String valueOrEmptySlot(String value, Boolean phoneSlot) {
    String cleared = BWM_MessagePayloadBuilder.blankChannelSlot(value);
    if (cleared != ' ') {
      return cleared;
    }
    if (String.isNotBlank(value)) {
      return ' ';
    }
    return phoneSlot == true ? ' ' : 'NA';
  }

  private static Boolean looksLikePhoneDigits(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    String digitsOnly = value.trim().replaceAll('[^0-9]', '');
    return digitsOnly.length() >= 10;
  }

  private static List<String> extractPlaceholderTypes(Map<String, Object> templateMap) {
    List<String> placeholderTypes = new List<String>();
    if (templateMap == null) {
      return placeholderTypes;
    }

    String templateText = readTemplateText(templateMap);
    if (String.isBlank(templateText)) {
      return placeholderTypes;
    }

    Matcher matcher = SMS_PLACEHOLDER_PATTERN.matcher(templateText);
    while (matcher.find()) {
      placeholderTypes.add(matcher.group(1).trim().toLowerCase());
    }

    return placeholderTypes;
  }

  /**
   * @description Resolves SMS body values for template placeholders.
   *              Call/contact phone slots use Owner Mobile → Phone only;
   *              blank when both are empty (never corporate).
   */
  private static List<String> buildVariableValues(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    Map<String, Object> templateMap,
    List<String> placeholderTypes
  ) {
    List<String> values = new List<String>();
    String templateText = readTemplateText(templateMap);
    String departmentName = BWM_FieldValueResolver.resolveDepartmentName(record);
    String ownerName = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Name');
    String ownerPhone = formatSmsPhoneValue(
      BWM_FieldValueResolver.resolveRecord(record, 'Owner.Phone'),
      settings
    );
    String recordName = BWM_FieldValueResolver.resolveRecord(record, 'Name');

    for (String placeholderType : placeholderTypes) {
      if (placeholderType == 'numeric') {
        values.add(ownerPhone);
        continue;
      }

      if (placeholderType == 'alphanumeric') {
        if (looksLikePhoneSlot(templateText, values.size())) {
          values.add(ownerPhone);
        } else if (String.isNotBlank(departmentName)) {
          values.add(departmentName);
        } else if (String.isNotBlank(recordName)) {
          values.add(recordName);
        } else {
          values.add('NA');
        }
        continue;
      }

      if (placeholderType == 'var') {
        if (looksLikePhoneSlot(templateText, values.size())) {
          values.add(ownerPhone);
        } else if (String.isNotBlank(ownerName)) {
          values.add(ownerName);
        } else if (String.isNotBlank(departmentName)) {
          values.add(departmentName);
        } else {
          values.add('NA');
        }
        continue;
      }

      values.add('NA');
    }

    return values;
  }

  private static Boolean isOwnerPhonePlaceholderSlot(
    String placeholderType,
    String templateText,
    Integer placeholderIndex
  ) {
    if (placeholderType == 'numeric') {
      return true;
    }
    if (placeholderType == 'alphanumeric' || placeholderType == 'var') {
      return looksLikePhoneSlot(templateText, placeholderIndex);
    }
    return false;
  }

  private static Boolean looksLikePhoneSlot(String templateText, Integer placeholderIndex) {
    if (String.isBlank(templateText)) {
      return false;
    }

    Matcher matcher = SMS_PLACEHOLDER_PATTERN.matcher(templateText);
    Integer currentIndex = 0;
    while (matcher.find()) {
      if (currentIndex == placeholderIndex) {
        Integer start = Math.max(0, matcher.start() - 40);
        String context = templateText.substring(start, matcher.start()).toLowerCase();
        return context.contains('call') ||
          context.contains('contact') ||
          context.contains('phone') ||
          context.contains('reach') ||
          context.contains('connect');
      }
      currentIndex++;
    }

    return false;
  }

  private static String formatSmsPhoneValue(
    String rawPhone,
    BWM_Messaging_Settings__mdt settings
  ) {
    if (String.isBlank(rawPhone)) {
      return '';
    }

    String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
      rawPhone,
      settings == null ? null : settings.Default_Country_Code__c
    );
    return String.isBlank(formattedPhone)
      ? rawPhone.trim()
      : formattedPhone.replaceAll('[^0-9]', '');
  }

  private static String readTemplateName(Map<String, Object> templateMap) {
    Object templateName = templateMap.get('TemplateName');
    if (templateName == null || String.isBlank(String.valueOf(templateName))) {
      templateName = templateMap.get('templateName');
    }
    return templateName == null ? null : String.valueOf(templateName);
  }

  private static String readTemplateText(Map<String, Object> templateMap) {
    Object templateText = templateMap.get('templateText');
    if (templateText == null || String.isBlank(String.valueOf(templateText))) {
      templateText = templateMap.get('TemplateText');
    }
    if (templateText == null || String.isBlank(String.valueOf(templateText))) {
      templateText = templateMap.get('MessageText');
    }
    return templateText == null ? null : String.valueOf(templateText);
  }

  private static String readDltTemplateId(Map<String, Object> templateMap) {
    Object dltTemplateId = templateMap.get('dltTemplateId');
    if (dltTemplateId == null || String.isBlank(String.valueOf(dltTemplateId))) {
      dltTemplateId = templateMap.get('dlttemplateid');
    }
    if (dltTemplateId == null || String.isBlank(String.valueOf(dltTemplateId))) {
      dltTemplateId = templateMap.get('DltTemplateId');
    }
    return dltTemplateId == null ? null : String.valueOf(dltTemplateId);
  }

  private static String normalizeName(String value) {
    return String.isBlank(value) ? '' : value.trim().toLowerCase();
  }

  @TestVisible
  static void clearCache() {
    templateByName = null;
  }
}