/**
 * @description   Resolves journey node merge tokens from Lead/Opportunity (and related)
 *                record field values.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_JourneyPayloadResolver {
  private static final Map<String, String> TOKEN_TO_FIELD_PATH = buildTokenMap();

  public static Map<String, Object> resolveDataPayload(
    SObject record,
    Map<String, Object> dataPayload,
    BWM_Template_Mapping__mdt mapping
  ) {
    List<String> params = mapping != null
      ? BWM_FieldValueResolver.resolveParamsForRecord(record, mapping)
      : new List<String>();
    return resolveDataPayload(record, dataPayload, mapping, params);
  }

  public static Map<String, Object> resolveDataPayload(
    SObject record,
    Map<String, Object> dataPayload,
    BWM_Template_Mapping__mdt mapping,
    List<String> params
  ) {
    return (Map<String, Object>) resolveValue(record, dataPayload, params);
  }

  private static Object resolveValue(
    SObject record,
    Object rawValue,
    List<String> params
  ) {
    if (rawValue == null) {
      return null;
    }

    if (rawValue instanceof Map<String, Object>) {
      Map<String, Object> input = (Map<String, Object>) rawValue;
      Map<String, Object> output = new Map<String, Object>();
      for (String key : input.keySet()) {
        Object child = input.get(key);
        Object resolvedEntry;
        // Journey JSON often stores placeholders as numbers (value: 4), not "4".
        // Resolve those for value/text keys only — never rewrite "index".
        if (
          isPlaceholderValueKey(key) &&
          isNumericPlaceholderPrimitive(child)
        ) {
          resolvedEntry = resolveToken(record, String.valueOf(child), params);
        } else {
          resolvedEntry = resolveValue(record, child, params);
        }
        resolvedEntry = resolvePlaceholderMapEntry(
          key,
          resolvedEntry,
          params,
          input.get('index')
        );
        output.put(key, resolvedEntry);
      }
      return output;
    }

    if (rawValue instanceof List<Object>) {
      List<Object> input = (List<Object>) rawValue;
      List<Object> output = new List<Object>();
      for (Object item : input) {
        output.add(resolveValue(record, item, params));
      }
      return output;
    }

    if (rawValue instanceof String) {
      return resolveToken(record, (String) rawValue, params);
    }

    return rawValue;
  }

  private static String resolveToken(
    SObject record,
    String token,
    List<String> params
  ) {
    if (String.isBlank(token)) {
      return '';
    }

    String trimmed = token.trim();
    if (isLiteralValue(trimmed)) {
      return trimmed;
    }

    if (Pattern.matches('^([1-9]|1[0-9]|20)$', trimmed)) {
      Integer oneBasedIndex = Integer.valueOf(trimmed);
      Integer index = oneBasedIndex - 1;
      if (params != null && index >= 0 && index < params.size()) {
        String resolved = nullToEmpty(params[index]).trim();
        // Reject self-referential placeholders (param value literally "4").
        if (
          String.isNotBlank(resolved) &&
          resolved != trimmed &&
          !Pattern.matches('^\\{\\{\\d+\\}\\}$', resolved)
        ) {
          return resolved;
        }
      }
      // Never send the digit itself (Bluewave shows "4"/"5"/"6" in WhatsApp).
      return fallbackForUnresolvedNumericPlaceholder(oneBasedIndex);
    }

    String fieldPath = lookupFieldPath(trimmed);
    if (String.isNotBlank(fieldPath)) {
      return BWM_FieldValueResolver.resolveRecord(record, fieldPath);
    }

    return trimmed;
  }

  private static Boolean isLiteralValue(String value) {
    String normalized = value.toLowerCase();
    return normalized.startsWith('http://') ||
      normalized.startsWith('https://') ||
      normalized.startsWith('91') ||
      normalized == '0' ||
      normalized == 'na';
  }

  private static String lookupFieldPath(String token) {
    String normalized = token.trim().toLowerCase().replace(' ', '_');
    if (TOKEN_TO_FIELD_PATH.containsKey(normalized)) {
      return TOKEN_TO_FIELD_PATH.get(normalized);
    }
    return TOKEN_TO_FIELD_PATH.containsKey(token.trim())
      ? TOKEN_TO_FIELD_PATH.get(token.trim())
      : null;
  }

  private static String nullToEmpty(String value) {
    return value == null ? '' : value;
  }

  /**
   * @description Fallback when journey JSON uses numeric placeholders (1..n) but the
   *              mapped param is blank or missing — never return the digit string.
   * @param oneBasedIndex WhatsApp variable index from the journey payload.
   * @return Corporate secondary contact defaults for 4/5/6; single space otherwise.
   */
  private static String fallbackForUnresolvedNumericPlaceholder(Integer oneBasedIndex) {
    if (oneBasedIndex >= 4 && oneBasedIndex <= 6) {
      return ' ';
    }
    return ' ';
  }

  private static Object resolvePlaceholderMapEntry(
    String key,
    Object resolvedValue,
    List<String> params,
    Object parentIndex
  ) {
    if (String.isBlank(key)) {
      return resolvedValue;
    }

    Integer oneBasedIndex = null;
    Matcher placeholderMatcher = Pattern.compile('^\\{\\{(\\d+)\\}\\}$').matcher(
      key.trim()
    );
    if (placeholderMatcher.matches()) {
      oneBasedIndex = Integer.valueOf(placeholderMatcher.group(1));
    } else if (isPlaceholderValueKey(key)) {
      oneBasedIndex = toOneBasedIndex(parentIndex);
    }

    if (oneBasedIndex == null) {
      return resolvedValue;
    }

    String asText = resolvedValue == null ? '' : String.valueOf(resolvedValue).trim();
    Boolean needsFill =
      String.isBlank(asText) ||
      asText == String.valueOf(oneBasedIndex) ||
      Pattern.matches('^\\{\\{\\d+\\}\\}$', asText);

    if (!needsFill) {
      return resolvedValue;
    }

    Integer index = oneBasedIndex - 1;
    if (params != null && index >= 0 && index < params.size()) {
      String fromParam = nullToEmpty(params[index]).trim();
      if (
        String.isNotBlank(fromParam) &&
        fromParam != String.valueOf(oneBasedIndex) &&
        !Pattern.matches('^\\{\\{\\d+\\}\\}$', fromParam)
      ) {
        return fromParam;
      }
    }

    return fallbackForUnresolvedNumericPlaceholder(oneBasedIndex);
  }

  private static Boolean isPlaceholderValueKey(String key) {
    if (String.isBlank(key)) {
      return false;
    }
    String normalized = key.trim().toLowerCase();
    return normalized == 'value' || normalized == 'text';
  }

  private static Boolean isNumericPlaceholderPrimitive(Object value) {
    if (value == null) {
      return false;
    }
    if (
      value instanceof Integer ||
      value instanceof Long ||
      value instanceof Decimal
    ) {
      Integer asInt = toOneBasedIndex(value);
      return asInt != null && asInt >= 1 && asInt <= 20;
    }
    if (value instanceof String) {
      String trimmed = ((String) value).trim();
      // Only small WhatsApp variable indexes — never phone numbers.
      return Pattern.matches('^([1-9]|1[0-9]|20)$', trimmed);
    }
    return false;
  }

  private static Integer toOneBasedIndex(Object rawIndex) {
    if (rawIndex == null) {
      return null;
    }
    if (rawIndex instanceof Integer) {
      Integer asInt = (Integer) rawIndex;
      if (asInt < 1 || asInt > 20) {
        return null;
      }
      return asInt;
    }
    if (rawIndex instanceof Long) {
      Long asLong = (Long) rawIndex;
      if (asLong < 1 || asLong > 20) {
        return null;
      }
      return Integer.valueOf(String.valueOf(asLong));
    }
    if (rawIndex instanceof Decimal) {
      Decimal asDecimal = (Decimal) rawIndex;
      if (asDecimal < 1 || asDecimal > 20) {
        return null;
      }
      return asDecimal.intValue();
    }
    String asText = String.valueOf(rawIndex).trim();
    if (String.isBlank(asText) || !Pattern.matches('^([1-9]|1[0-9]|20)$', asText)) {
      return null;
    }
    return Integer.valueOf(asText);
  }

  private static Map<String, String> buildTokenMap() {
    Map<String, String> tokenMap = new Map<String, String>();
    tokenMap.put('lead.owner.name', 'Owner.Name');
    tokenMap.put('lead.owner.phone', 'Owner.Phone');
    tokenMap.put('lead.owner.email', 'Owner.Email');
    tokenMap.put('lead.owner', 'Owner.Name');
    tokenMap.put('lead_owner', 'Owner.Name');
    tokenMap.put('lead_owner_name', 'Owner.Name');
    tokenMap.put('lead_owner_phone', 'Owner.Phone');
    tokenMap.put('lead_owner_email', 'Owner.Email');
    tokenMap.put('Lead.Owner.name', 'Owner.Name');
    tokenMap.put('Lead.Owner.phone', 'Owner.Phone');
    tokenMap.put('Lead.Owner.email', 'Owner.Email');
    tokenMap.put('Lead.Owner.Phone', 'Owner.Phone');
    tokenMap.put('Lead.Owner', 'Owner.Name');
    tokenMap.put('department.crm.name', BWM_MessagingConstants.FIELD_CRM_USER_NAME);
    tokenMap.put('department.crm.phone', BWM_MessagingConstants.FIELD_CRM_USER_PHONE);
    tokenMap.put('department.crm.email', BWM_MessagingConstants.FIELD_CRM_USER_EMAIL);
    tokenMap.put('department_name_1', 'Department_Name__c');
    tokenMap.put('department_name_2', 'Department_Name__c');
    tokenMap.put('department_crm_name', BWM_MessagingConstants.FIELD_CRM_USER_NAME);
    tokenMap.put('department_crm_phone', BWM_MessagingConstants.FIELD_CRM_USER_PHONE);
    tokenMap.put('department_crm_email', BWM_MessagingConstants.FIELD_CRM_USER_EMAIL);
    tokenMap.put('Department_crm_name', BWM_MessagingConstants.FIELD_CRM_USER_NAME);
    tokenMap.put('Department_crm_phone', BWM_MessagingConstants.FIELD_CRM_USER_PHONE);
    tokenMap.put('Department_crm_number', BWM_MessagingConstants.FIELD_CRM_USER_PHONE);
    tokenMap.put('Department_crm_email', BWM_MessagingConstants.FIELD_CRM_USER_EMAIL);
    tokenMap.put('department_crm_number', BWM_MessagingConstants.FIELD_CRM_USER_PHONE);
    tokenMap.put('product_brief', BWM_MessagingConstants.FIELD_WHATSAPP_PRODUCT_BRIEF);
    tokenMap.put('Product_Brief', BWM_MessagingConstants.FIELD_WHATSAPP_PRODUCT_BRIEF);
    tokenMap.put('opportunity.owner.name', 'Owner.Name');
    tokenMap.put('opportunity.owner.phone', 'Owner.Phone');
    tokenMap.put('opportunity.owner.email', 'Owner.Email');
    tokenMap.put('opportunity.owner', 'Owner.Name');
    tokenMap.put('opportunity_owner_name', 'Owner.Name');
    tokenMap.put('opportunity_owner_phone', 'Owner.Phone');
    tokenMap.put('opportunity_owner_number', 'Owner.Phone');
    tokenMap.put('opportunity_owner_email', 'Owner.Email');
    tokenMap.put('Opportunity_Owner_name', 'Owner.Name');
    tokenMap.put('Opportunity_Owner_phone', 'Owner.Phone');
    tokenMap.put('Opportunity_Owner_number', 'Owner.Phone');
    tokenMap.put('Opportunity_Owner_email', 'Owner.Email');
    tokenMap.put('Opportunity_owner_name', 'Owner.Name');
    tokenMap.put('Opportunity_owner_number', 'Owner.Phone');
    tokenMap.put('Opportunity_owner_email', 'Owner.Email');
    tokenMap.put('department.name', 'Department_Name__c');
    tokenMap.put('Department.name', 'Department_Name__c');
    tokenMap.put('department.crm.call', BWM_MessagingConstants.FIELD_CRM_USER_PHONE);
    return tokenMap;
  }
}