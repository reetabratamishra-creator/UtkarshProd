/**
 * @description   Validates CRM-user/owner journey parameters for campaign Journey
 *                sends.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class BWM_CampaignJourneyParamService {
  /**
   * @description Returns true when the record Owner name matches CRM_User_Name_Formula__c.
   * @param record Lead or Opportunity (other types return false).
   * @return True when CRM user name equals Owner name.
   */
  public static Boolean ownerMatchesCrmUserName(SObject record) {
    if (record == null) {
      return false;
    }

    String crmUserName;
    String ownerName;

    if (record instanceof Lead) {
      Lead leadRecord = (Lead) record;
      crmUserName = safeText(leadRecord, 'CRM_User_Name_Formula__c');
      ownerName = leadRecord.Owner == null ? null : leadRecord.Owner.Name;
    } else if (record instanceof Opportunity) {
      Opportunity opportunityRecord = (Opportunity) record;
      crmUserName = safeText(opportunityRecord, 'CRM_User_Name_Formula__c');
      ownerName = opportunityRecord.Owner == null
        ? null
        : opportunityRecord.Owner.Name;
    } else {
      return false;
    }

    return String.isNotBlank(crmUserName) &&
      String.isNotBlank(ownerName) &&
      crmUserName.trim().equalsIgnoreCase(ownerName.trim());
  }

  /**
   * @description True for enquiry-style templates that show Rudra and Bhagyashree
   *              names in the WhatsApp layout with {{1}}/{{2}} phone slots only.
   */
  public static Boolean isDualCorporateSupportPhoneTemplate(
    BWM_Template_Mapping__mdt mapping
  ) {
    if (mapping == null) {
      return false;
    }
    return mapping.Param1_Field__c ==
      BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_1 &&
      mapping.Param2_Field__c ==
      BWM_MessagingConstants.FIELD_CORPORATE_SUPPORT_PHONE_2;
  }

  /**
   * @description True for Prospect + product-department enquiry journeys where
   *              {{4}} is brochure/department, {{5}}–{{7}} are always Lead Owner
   *              contact — never replaced with central support when Owner = CRM user.
   */
  public static Boolean isProspectEnqDeptOwnerContactTemplate(
    BWM_Template_Mapping__mdt mapping
  ) {
    if (mapping == null) {
      return false;
    }
    return mapping.Journey_Name__c == 'prospect_enq_dept';
  }

  /**
   * @description True for dealer sales-assign journeys where {{4}}–{{6}} are
   *              customer Email / City / State — never secondary CRM contact slots.
   */
  public static Boolean isDealerSalesAssignTemplate(
    BWM_Template_Mapping__mdt mapping
  ) {
    if (mapping == null) {
      return false;
    }
    return mapping.Journey_Name__c == 'dealer_sales_assign' ||
      mapping.Trigger_Point__c ==
      BWM_MessagingConstants.TRIGGER_OPPORTUNITY_REFER_TO_DEALER;
  }

  /**
   * @description When Owner matches CRM user, replace secondary corporate-support
   *              params with owner name + central phone/email. Skipped for dual-phone
   *              enquiry templates that intentionally use Rudra/Bhagyashree numbers,
   *              prospect_enq_dept where owner contact slots are primary, and
   *              dealer_sales_assign where {{4}}–{{6}} are customer details.
   */
  public static List<String> applyMessagingContactParamFixes(
    SObject record,
    List<String> params,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (
      isDualCorporateSupportPhoneTemplate(mapping) ||
      isProspectEnqDeptOwnerContactTemplate(mapping) ||
      isDealerSalesAssignTemplate(mapping)
    ) {
      return params;
    }
    // Auto journeys must not invent extra WhatsApp slots. Templates with only
    // {{1}}–{{3}} or {{1}}–{{4}} stay at their mapped size.
    return applySecondaryContactOverride(record, params);
  }

  public static List<String> applyCampaignContactParamFixes(
    SObject record,
    List<String> params
  ) {
    return applyCampaignContactParamFixes(record, params, null);
  }

  public static List<String> applyCampaignContactParamFixes(
    SObject record,
    List<String> params,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (
      isDualCorporateSupportPhoneTemplate(mapping) ||
      isProspectEnqDeptOwnerContactTemplate(mapping) ||
      isDealerSalesAssignTemplate(mapping)
    ) {
      return params;
    }
    List<String> updated = padSecondaryContactSlots(params);
    updated = applySecondaryContactOverride(record, updated);
    return fillBlankSecondaryContactParams(record, updated, mapping);
  }

  /**
   * @description Ensures 6 param slots for dual-contact templates (primary trio present
   *              but secondary slots missing). Does not pad 1–2 param templates.
   * @param params Existing resolved params.
   * @return Params padded with blanks to size 6 when size is 3–5; otherwise unchanged.
   */
  public static List<String> padSecondaryContactSlots(List<String> params) {
    if (params == null) {
      return params;
    }
    if (params.size() >= 3 && params.size() < 6) {
      List<String> padded = new List<String>(params);
      while (padded.size() < 6) {
        padded.add('');
      }
      return padded;
    }
    return params;
  }

  /**
   * @description When Owner matches CRM user, overwrite secondary contact params with
   *              Owner name + central campaign phone/email.
   * @param record Lead/Opportunity being messaged.
   * @param params Param list that must already contain at least 6 values.
   * @return Updated params, or original when override does not apply.
   */
  public static List<String> applySecondaryContactOverride(
    SObject record,
    List<String> params
  ) {
    if (!ownerMatchesCrmUserName(record) || params == null || params.size() < 6) {
      return params;
    }

    List<String> updated = new List<String>(params);
    String ownerName = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Name');
    updated[3] = String.isNotBlank(ownerName) ? ownerName.trim() : updated[3];
    updated[4] = BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE;
    updated[5] = BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL;
    return updated;
  }

  /**
   * @description Fills blank or placeholder {{4}}/{{5}}/{{6}} secondary contact values
   *              with corporate support defaults so WhatsApp does not show literal indexes.
   * @param params Param list; only lists with size >= 6 are adjusted.
   * @return Params with secondary slots filled; unchanged when size < 6.
   */
  public static List<String> fillBlankSecondaryContactParams(List<String> params) {
    return fillBlankSecondaryContactParams(null, params, null);
  }

  public static List<String> fillBlankSecondaryContactParams(
    SObject record,
    List<String> params,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (
      isDualCorporateSupportPhoneTemplate(mapping) ||
      isProspectEnqDeptOwnerContactTemplate(mapping) ||
      isDealerSalesAssignTemplate(mapping) ||
      params == null ||
      params.size() < 6
    ) {
      return params;
    }

    List<String> updated = new List<String>(params);
    if (isMissingSecondaryValue(updated[3])) {
      updated[3] = resolveBlankSecondaryContactName(record);
    }
    if (isMissingSecondaryValue(updated[4])) {
      updated[4] = resolveSecondaryContactPhone(record);
    }
    if (isMissingSecondaryValue(updated[5])) {
      updated[5] = resolveSecondaryContactEmail(record);
    }
    return updated;
  }

  public static String resolveSecondaryContactName(SObject record) {
    if (ownerMatchesCrmUserName(record)) {
      String ownerName = BWM_FieldValueResolver.resolveRecord(record, 'Owner.Name');
      if (String.isNotBlank(ownerName)) {
        return ownerName.trim();
      }
    }
    String crmUserName = BWM_FieldValueResolver.resolveRecord(
      record,
      BWM_MessagingConstants.FIELD_CRM_USER_NAME
    );
    if (String.isNotBlank(crmUserName)) {
      return crmUserName.trim();
    }
    return '';
  }

  public static String resolveSecondaryContactPhone(SObject record) {
    if (ownerMatchesCrmUserName(record)) {
      return BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE;
    }
    String crmPhone = BWM_FieldValueResolver.resolveRecord(
      record,
      BWM_MessagingConstants.FIELD_CRM_USER_PHONE
    );
    return String.isNotBlank(crmPhone) ? crmPhone.trim() : '';
  }

  public static String resolveSecondaryContactEmail(SObject record) {
    if (ownerMatchesCrmUserName(record)) {
      return BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL;
    }
    String crmEmail = BWM_FieldValueResolver.resolveRecord(
      record,
      BWM_MessagingConstants.FIELD_CRM_USER_EMAIL
    );
    return String.isNotBlank(crmEmail) ? crmEmail.trim() : '';
  }

  private static String resolveBlankSecondaryContactName(SObject record) {
    return resolveSecondaryContactName(record);
  }

  /**
   * @description True when a secondary contact slot is blank, whitespace, or a bare
   *              variable index like "4"/"5"/"6".
   * @param value Param value to evaluate.
   * @return True when the value should be replaced with a corporate default.
   */
  @TestVisible
  private static Boolean isMissingSecondaryValue(String value) {
    if (String.isBlank(value)) {
      return true;
    }
    String trimmed = value.trim();
    return trimmed == '4' ||
      trimmed == '5' ||
      trimmed == '6' ||
      trimmed == '{{4}}' ||
      trimmed == '{{5}}' ||
      trimmed == '{{6}}' ||
      trimmed.equalsIgnoreCase('NA');
  }

  /**
   * @description RCS bodyData override for secondary CRM phone/email when Owner = CRM user.
   * @param record Lead/Opportunity being messaged.
   * @param bodyData RCS named body placeholders.
   * @return Updated bodyData map.
   */
  public static Map<String, Object> applyRcsBodyDataOverride(
    SObject record,
    Map<String, Object> bodyData
  ) {
    return applyRcsBodyDataOverride(record, bodyData, null);
  }

  public static Map<String, Object> applyRcsBodyDataOverride(
    SObject record,
    Map<String, Object> bodyData,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (
      isDualCorporateSupportPhoneTemplate(mapping) ||
      isProspectEnqDeptOwnerContactTemplate(mapping) ||
      !ownerMatchesCrmUserName(record) ||
      bodyData == null ||
      bodyData.isEmpty()
    ) {
      return bodyData;
    }

    Map<String, Object> updated = new Map<String, Object>(bodyData);
    for (String key : updated.keySet()) {
      if (String.isBlank(key)) {
        continue;
      }
      String normalized = key.trim().toLowerCase();
      if (isOwnerCrmSecondaryPhoneParam(normalized)) {
        updated.put(key, BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_PHONE);
      } else if (isOwnerCrmSecondaryEmailParam(normalized)) {
        updated.put(key, BWM_MessagingConstants.CAMPAIGN_OWNER_CRM_MATCH_EMAIL);
      } else if (isOwnerCrmSecondaryNameParam(normalized)) {
        updated.put(
          key,
          BWM_FieldValueResolver.resolveRecord(record, 'Owner.Name')
        );
      }
    }
    return fillBlankRcsSecondaryContactParams(record, updated, mapping);
  }

  /**
   * @description Fills blank RCS secondary contact placeholders used by dual-contact journeys.
   * @param bodyData RCS bodyData map.
   * @return Updated map with corporate defaults for blank secondary keys.
   */
  public static Map<String, Object> fillBlankRcsSecondaryContactParams(
    Map<String, Object> bodyData
  ) {
    return fillBlankRcsSecondaryContactParams(null, bodyData, null);
  }

  public static Map<String, Object> fillBlankRcsSecondaryContactParams(
    SObject record,
    Map<String, Object> bodyData,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (
      isDualCorporateSupportPhoneTemplate(mapping) ||
      isProspectEnqDeptOwnerContactTemplate(mapping) ||
      bodyData == null ||
      bodyData.isEmpty()
    ) {
      return bodyData;
    }

    Map<String, Object> updated = new Map<String, Object>(bodyData);
    for (String key : new List<String>(updated.keySet())) {
      if (String.isBlank(key)) {
        continue;
      }
      String normalized = key.trim().toLowerCase();
      Object raw = updated.get(key);
      String value = raw == null ? '' : String.valueOf(raw).trim();
      if (String.isNotBlank(value)) {
        continue;
      }
      if (isOwnerCrmSecondaryNameParam(normalized)) {
        updated.put(key, resolveBlankSecondaryContactName(record));
      } else if (isOwnerCrmSecondaryPhoneParam(normalized) || normalized == '{{5}}') {
        updated.put(key, resolveSecondaryContactPhone(record));
      } else if (isOwnerCrmSecondaryEmailParam(normalized) || normalized == '{{6}}') {
        updated.put(key, resolveSecondaryContactEmail(record));
      }
    }
    return updated;
  }

  private static Boolean isOwnerCrmSecondaryPhoneParam(String normalized) {
    return normalized == 'department_crm_phone';
  }

  private static Boolean isOwnerCrmSecondaryEmailParam(String normalized) {
    return normalized == 'department_crm_email';
  }

  private static Boolean isOwnerCrmSecondaryNameParam(String normalized) {
    return normalized == 'department_crm_name' ||
      normalized == '{{4}}' ||
      normalized.contains('crm_name');
  }

  private static String safeText(SObject record, String fieldName) {
    if (record == null || String.isBlank(fieldName)) {
      return null;
    }
    try {
      Object value = record.get(fieldName);
      return value == null ? null : String.valueOf(value);
    } catch (Exception ex) {
      return null;
    }
  }
}