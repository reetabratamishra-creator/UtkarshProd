/**
 * @description   Builds Bluewave Journey payloads including WhatsApp, RCS, and SMS
 *                nodes from template mappings.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class BWM_MessagePayloadBuilder {
  /**
   * @description SMS variable values for a campaign send, using the auto-journey mapping.
   */
  public static Map<String, Object> smsMappingsForCampaign(
    BWM_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (mapping == null || record == null) {
      return new Map<String, Object>();
    }
    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(record, mapping);
    params = BWM_CampaignJourneyParamService.applyMessagingContactParamFixes(
      record,
      params,
      mapping
    );
    return resolveSmsVariableMappings(mapping, record, params);
  }

  /**
   * @description RCS body values for a campaign send, using the auto-journey mapping.
   */
  public static Map<String, Object> rcsBodyForCampaign(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (mapping == null || record == null) {
      return new Map<String, Object>();
    }
    Map<String, Object> node = buildRcsJourneyNode(settings, mapping, record, false);
    Map<String, Object> data = (Map<String, Object>) node.get('data');
    Object bodyData = data == null ? null : data.get('bodyData');
    return bodyData instanceof Map<String, Object>
      ? (Map<String, Object>) bodyData
      : new Map<String, Object>();
  }

  public static String buildJourneyPayloadForRecord(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    String phoneNumber
  ) {
    return buildJourneyPayloadForRecord(
      settings,
      mapping,
      record,
      phoneNumber,
      false
    );
  }

  public static String buildJourneyPayloadForRecord(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    String phoneNumber,
    Boolean includeDocumentFileName
  ) {
    return buildJourneyPayloadForRecord(
      settings,
      mapping,
      record,
      phoneNumber,
      includeDocumentFileName,
      false
    );
  }

  public static String buildJourneyPayloadForRecord(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    String phoneNumber,
    Boolean includeDocumentFileName,
    Boolean forCampaignSend
  ) {
    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      record,
      mapping
    );
    params = BWM_CampaignJourneyParamService.applyMessagingContactParamFixes(
      record,
      params,
      mapping
    );
    // RCS and SMS keep the auto-journey values. Campaign blank-fill applies to WhatsApp only.
    List<String> messagingParams = params;
    if (forCampaignSend == true) {
      params = BWM_CampaignJourneyParamService.fillBlankSecondaryContactParams(
        record,
        params,
        mapping
      );
    }

    Map<String, Object> nodes = new Map<String, Object>();
    Integer nodeIndex = 1;

    if (String.isNotBlank(mapping.WhatsApp_Template_Name__c)) {
      nodes.put(String.valueOf(nodeIndex), buildWhatsAppJourneyNode(
        settings,
        mapping,
        record,
        params,
        includeDocumentFileName == true
      ));
      nodeIndex++;
    }

    if (String.isNotBlank(mapping.RCS_Template_Name__c)) {
      nodes.put(
        String.valueOf(nodeIndex),
        buildRcsJourneyNode(
          settings,
          mapping,
          record,
          false
        )
      );
      nodeIndex++;
    }

    if (String.isNotBlank(mapping.SMS_Template_Name__c)) {
      nodes.put(
        String.valueOf(nodeIndex),
        buildSmsJourneyNode(
          mapping,
          record,
          messagingParams
        )
      );
    }

    Map<String, Object> payload = new Map<String, Object>{
      'channel' => BWM_MessagingConstants.CHANNEL_JOURNEY,
      'to' => new List<String>{ phoneNumber },
      'content' => new Map<String, Object>{
        'data' => new Map<String, Object>{
          'journeyname' => mapping.Journey_Name__c,
          'journeypayload' => new Map<String, Object>{ 'nodes' => nodes }
        }
      }
    };

    return JSON.serialize(payload);
  }

  private static Map<String, Object> buildWhatsAppJourneyNode(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    List<String> params,
    Boolean includeDocumentFileName
  ) {
    Map<String, Object> data = new Map<String, Object>{
      'templateName' => mapping.WhatsApp_Template_Name__c,
      'bodyVariables' => buildIndexedVariables(params),
      'buttonVariables' => new List<Object>(),
      'carouselCards' => new List<Object>()
    };

    applyWhatsAppHeader(
      settings,
      mapping,
      record,
      data,
      includeDocumentFileName
    );

    return new Map<String, Object>{
      'templateType' => 'WHATSAPP',
      'data' => data
    };
  }

  private static void applyWhatsAppHeader(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    Map<String, Object> data,
    Boolean includeDocumentFileName
  ) {
    Boolean wantsDocumentHeader =
      mapping.Include_Brochure_Header__c == true ||
      mapping.Brochure_Attachment_Mode__c ==
        BWM_MessagingConstants.BROCHURE_ATTACH_CORPORATE ||
      mapping.Brochure_Attachment_Mode__c ==
        BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT;

    if (wantsDocumentHeader) {
      String headerValue = resolveDocumentHeaderValue(settings, mapping, record);
      if (String.isNotBlank(headerValue)) {
        data.put('headerFormat', BWM_MessagingConstants.WHATSAPP_HEADER_DOCUMENT);
        Map<String, Object> headerVariable = new Map<String, Object>{
          'index' => 1,
          'type' => 'static',
          'value' => headerValue,
          'format' => 'document'
        };
        // Always send a sanitized fileName so WhatsApp does not use URL basename
        // like crash_barrier(2).pdf. Corporate brochure always uses corporate_brochure.pdf.
        if (isValidWhatsAppDocumentUrl(headerValue)) {
          String brochureMode = mapping.Brochure_Attachment_Mode__c;
          if (
            String.isBlank(brochureMode) ||
            brochureMode == BWM_MessagingConstants.BROCHURE_ATTACH_NONE
          ) {
            brochureMode = BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT;
          }
          String documentFileName = resolveDocumentFileName(
            record,
            headerValue,
            brochureMode
          );
          if (String.isNotBlank(documentFileName)) {
            headerVariable.put('fileName', documentFileName);
          }
        }
        data.put('headerVariables', new List<Object>{ headerVariable });
        return;
      }
    }

    if (
      mapping.WhatsApp_Header_Format__c ==
      BWM_MessagingConstants.WHATSAPP_HEADER_TEXT
    ) {
      String headerValue = BWM_FieldValueResolver.resolveRecord(
        record,
        mapping.WhatsApp_Header_Value_Field__c
      );
      if (String.isBlank(headerValue)) {
        headerValue = BWM_FieldValueResolver.resolveDepartmentName(record);
      }
      data.put('headerFormat', BWM_MessagingConstants.WHATSAPP_HEADER_TEXT);
      data.put(
        'headerVariables',
        new List<Object>{
          new Map<String, Object>{
            'index' => 1,
            'type' => 'static',
            'value' => String.isNotBlank(headerValue) ? headerValue.trim() : 'NA',
            'format' => 'text'
          }
        }
      );
      return;
    }

    // No header templates (e.g. u_prospect_de_not_rec): omit header keys.
    // Sending headerFormat="" can make Bluewave enqueue OK but WhatsApp fail.
  }

  private static Map<String, Object> buildRcsJourneyNode(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    Boolean forCampaignSend
  ) {
    Map<String, Object> fallbackPlaceholderMap = BWM_JourneyDefinitionService.getRcsBodyDataTemplate(
      mapping.Journey_Name__c
    );
    Map<String, Object> bodyData = BWM_RcsDirectPayloadBuilder.buildNamedBodyDataForJourney(
      settings,
      mapping.RCS_Template_Name__c,
      record,
      fallbackPlaceholderMap
    );
    bodyData = BWM_CampaignJourneyParamService.applyRcsBodyDataOverride(
      record,
      bodyData,
      mapping
    );
    if (forCampaignSend) {
      bodyData = BWM_CampaignJourneyParamService.fillBlankRcsSecondaryContactParams(
        record,
        bodyData,
        mapping
      );
    }
    blankStringMap(bodyData);

    return new Map<String, Object>{
      'templateType' => 'RCSMESSAGE',
      'data' => new Map<String, Object>{
        'templateName' => mapping.RCS_Template_Name__c,
        'headerData' => new Map<String, Object>(),
        'bodyData' => bodyData,
        'footerData' => new Map<String, Object>(),
        'cardData' => new List<Object>()
      }
    };
  }

  private static Map<String, Object> buildSmsJourneyNode(
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    List<String> params
  ) {
    Map<String, Object> variableMappings = resolveSmsVariableMappings(
      mapping,
      record,
      params
    );

    return new Map<String, Object>{
      'templateType' => 'SMS',
      'data' => new Map<String, Object>{
        'templateName' => mapping.SMS_Template_Name__c,
        'variableMappings' => variableMappings
      }
    };
  }

  /**
   * @description Builds SMS journey variableMappings from journey JSON tokens,
   *              falling back to template Param fields only when compatible.
   *              Phone tokens (e.g. Lead.Owner.Phone) resolve Owner Mobile/Phone;
   *              blank becomes a space — never Param1 Owner.Name via index alignment.
   */
  private static Map<String, Object> resolveSmsVariableMappings(
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    List<String> params
  ) {
    Map<String, Object> templateMappings = BWM_JourneyDefinitionService.getSmsVariableMappingsTemplate(
      mapping.Journey_Name__c
    );
    Map<String, Object> paramFallbackMappings = buildSmsVariableMappingsFromParams(
      mapping,
      record,
      params
    );

    if (!templateMappings.isEmpty()) {
      Map<String, Object> resolvedMappings = (Map<String, Object>) BWM_JourneyPayloadResolver.resolveDataPayload(
        record,
        templateMappings,
        mapping
      );
      Map<String, Object> variableMappings = new Map<String, Object>();
      for (String key : resolvedMappings.keySet()) {
        String value = nullToEmptyTrim(resolvedMappings.get(key));
        String token = nullToEmptyTrim(templateMappings.get(key));
        if (
          isSmsPhoneMappingToken(token) ||
          isOwnerPhoneIndexToken(mapping, token, key)
        ) {
          value = BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(record, value);
          value = finalizeSmsJourneyOwnerPhoneValue(value);
        } else if (String.isBlank(value) && paramFallbackMappings.containsKey(key)) {
          value = nullToEmptyTrim(paramFallbackMappings.get(key));
        }
        variableMappings.put(key, blankChannelSlot(value));
      }
      if (!variableMappings.isEmpty()) {
        return variableMappings;
      }
    }

    return paramFallbackMappings;
  }

  /**
   * @description True when the journey SMS token is an owner/contact phone field.
   */
  private static Boolean isSmsPhoneMappingToken(String token) {
    if (String.isBlank(token)) {
      return false;
    }
    String normalized = token.trim().toLowerCase();
    return normalized.contains('phone') ||
      normalized.contains('mobile') ||
      normalized.contains('contact_no');
  }

  private static Map<String, Object> buildSmsVariableMappingsFromParams(
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    List<String> params
  ) {
    Map<String, Object> variableMappings = new Map<String, Object>();
    if (params == null || params.isEmpty()) {
      return variableMappings;
    }

    // Prospect_not_resp-style SMS: one slot = Owner.Phone, but Param1 is Owner.Name
    // for WhatsApp and RCS_SMS_Param_Limit__c = 1 would otherwise send the name.
    if (
      mapping != null &&
      mapping.RCS_SMS_Param_Limit__c == 1 &&
      isOwnerNameFieldPath(mapping.Param1_Field__c) &&
      isOwnerPhoneFieldPath(mapping.Param2_Field__c) &&
      params.size() >= 2
    ) {
      variableMappings.put(
        '1',
        finalizeSmsJourneyOwnerPhoneValue(
          BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(
            record,
            nullToEmptyTrim(params[1])
          )
        )
      );
      return variableMappings;
    }

    List<String> smsParams = paramsForSms(mapping, params);
    for (Integer index = 0; index < smsParams.size(); index++) {
      String fieldPath = smsParamFieldPath(mapping, index);
      String value = nullToEmptyTrim(smsParams[index]);
      if (isOwnerPhoneFieldPath(fieldPath) || isSmsPhoneMappingToken(fieldPath)) {
        value = finalizeSmsJourneyOwnerPhoneValue(
          BWM_FieldValueResolver.resolveSmsOwnerPhoneSlot(record, value)
        );
      }
      variableMappings.put(String.valueOf(index + 1), blankChannelSlot(value));
    }
    return variableMappings;
  }

  private static Boolean isOwnerPhoneIndexToken(
    BWM_Template_Mapping__mdt mapping,
    String token,
    String key
  ) {
    String indexToken = String.isNotBlank(token) ? token : key;
    if (
      String.isBlank(indexToken) ||
      !Pattern.matches('^([1-9]|1[0-9]|20)$', indexToken.trim())
    ) {
      return false;
    }
    return mapping != null &&
      mapping.RCS_SMS_Param_Limit__c == 1 &&
      isOwnerNameFieldPath(mapping.Param1_Field__c) &&
      isOwnerPhoneFieldPath(mapping.Param2_Field__c);
  }

  private static String smsParamFieldPath(
    BWM_Template_Mapping__mdt mapping,
    Integer zeroBasedIndex
  ) {
    if (mapping == null || zeroBasedIndex == null || zeroBasedIndex < 0) {
      return '';
    }
    if (zeroBasedIndex == 0) {
      return mapping.Param1_Field__c;
    }
    if (zeroBasedIndex == 1) {
      return mapping.Param2_Field__c;
    }
    if (zeroBasedIndex == 2) {
      return mapping.Param3_Field__c;
    }
    if (zeroBasedIndex == 3) {
      return mapping.Param4_Field__c;
    }
    if (zeroBasedIndex == 4) {
      return mapping.Param5_Field__c;
    }
    if (zeroBasedIndex == 5) {
      return mapping.Param6_Field__c;
    }
    if (zeroBasedIndex == 6) {
      return mapping.Param7_Field__c;
    }
    if (zeroBasedIndex == 7) {
      return mapping.Param8_Field__c;
    }
    return '';
  }

  private static Boolean isOwnerPhoneFieldPath(String fieldPath) {
    return fieldPath == 'Owner.Phone' || fieldPath == 'Owner.MobilePhone';
  }

  private static Boolean isOwnerNameFieldPath(String fieldPath) {
    return fieldPath == 'Owner.Name';
  }

  private static String nullToEmptyTrim(Object rawValue) {
    if (rawValue == null) {
      return '';
    }
    return String.valueOf(rawValue).trim();
  }

  private static List<Object> buildIndexedVariables(List<String> params) {
    List<Object> variables = new List<Object>();
    for (Integer index = 0; index < params.size(); index++) {
      // Keep every index so template slots stay aligned. Empty → space so
      // Bluewave/Meta do not leave a literal {{n}} in the delivered message.
      String value = whatsAppSafeParamValue(params[index]);
      variables.add(
        new Map<String, Object>{
          'index' => index + 1,
          'type' => 'static',
          'value' => value,
          'format' => '{{' + String.valueOf(index + 1) + '}}'
        }
      );
    }
    return variables;
  }

  /**
   * @description Owner-phone SMS slots: owner Mobile/Phone digits only. A single
   *              space when empty so Bluewave does not keep the template sample
   *              (e.g. Lead.Owner.Phone). Never CRM or other fallback numbers.
   */
  private static String finalizeSmsJourneyOwnerPhoneValue(String value) {
    return blankChannelSlot(value);
  }

  /**
   * @description Empty merge values and leftover field tokens (Lead.Owner.Phone)
   *              become a single space so Bluewave does not keep the template sample.
   */
  public static String blankChannelSlot(String value) {
    if (String.isBlank(value) || isUnresolvedMergeToken(value)) {
      return ' ';
    }
    return value.trim();
  }

  /**
   * @description Replaces blank SMS and RCS merge values on a resolved journey
   *              document. WhatsApp nodes are left unchanged.
   */
  public static Map<String, Object> blankMissingSmsAndRcsValues(
    Map<String, Object> payload
  ) {
    if (payload == null) {
      return payload;
    }
    Map<String, Object> journeyPayload = (Map<String, Object>) payload.get(
      'journeypayload'
    );
    if (journeyPayload == null) {
      return payload;
    }
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    if (nodes == null) {
      return payload;
    }
    for (String nodeKey : nodes.keySet()) {
      Map<String, Object> node = (Map<String, Object>) nodes.get(nodeKey);
      if (node == null) {
        continue;
      }
      String templateType = (String) node.get('templateType');
      Map<String, Object> data = (Map<String, Object>) node.get('data');
      if (data == null) {
        continue;
      }
      if (templateType == 'SMS') {
        blankStringMap(data.get('variableMappings'));
      } else if (templateType == 'RCSMESSAGE') {
        blankStringMap(data.get('bodyData'));
      }
    }
    return payload;
  }

  private static void blankStringMap(Object rawMap) {
    if (!(rawMap instanceof Map<String, Object>)) {
      return;
    }
    Map<String, Object> values = (Map<String, Object>) rawMap;
    for (String key : values.keySet()) {
      Object rawValue = values.get(key);
      if (rawValue != null && !(rawValue instanceof String)) {
        continue;
      }
      values.put(key, blankChannelSlot(rawValue == null ? '' : (String) rawValue));
    }
  }

  private static Boolean isUnresolvedMergeToken(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    return MERGE_TOKENS.contains(value.trim().toLowerCase());
  }

  private static final Set<String> MERGE_TOKENS = new Set<String>{
    'lead.owner',
    'lead.owner.name',
    'lead.owner.phone',
    'lead.owner.email',
    'lead_owner',
    'lead_owner_name',
    'lead_owner_phone',
    'lead_owner_email',
    'owner.name',
    'owner.phone',
    'owner.email',
    'owner.mobilephone',
    'opportunity.owner',
    'opportunity.owner.name',
    'opportunity.owner.phone',
    'opportunity.owner.email',
    'opportunity.owner.number',
    'opportunity_owner',
    'opportunity_owner_name',
    'opportunity_owner_phone',
    'opportunity_owner_number',
    'opportunity_owner_email',
    'department.name',
    'department.crm.name',
    'department.crm.phone',
    'department.crm.email',
    'department.crm.number',
    'department.crm.call',
    'department_name_1',
    'department_name_2',
    'department_name_3',
    'department_crm_name',
    'department_crm_phone',
    'department_crm_email',
    'department_crm_number',
    'product_brief',
    'rudra_number',
    'bhagyashree_number'
  };

  /**
   * WhatsApp/Bluewave leave literal {{n}} when value is empty. A single space
   * keeps the slot filled without showing Lead phone or a placeholder.
   */
  private static String whatsAppSafeParamValue(String rawValue) {
    if (rawValue == null) {
      return ' ';
    }
    String trimmed = rawValue.trim();
    return String.isBlank(trimmed) ? ' ' : trimmed;
  }

  private static List<String> paramsForSms(
    BWM_Template_Mapping__mdt mapping,
    List<String> params
  ) {
    if (mapping.RCS_SMS_Param_Limit__c == null || mapping.RCS_SMS_Param_Limit__c <= 0) {
      return params;
    }

    Integer limitCount = mapping.RCS_SMS_Param_Limit__c.intValue();
    List<String> limited = new List<String>();
    for (Integer index = 0; index < params.size() && limited.size() < limitCount; index++) {
      limited.add(params[index]);
    }
    return limited;
  }

  private static String resolveDocumentHeaderValue(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (
      isValidWhatsAppDocumentUrl(mapping.Document_Header_URL__c) &&
      !BWM_BrochureService.isSandboxOrInaccessibleUrl(mapping.Document_Header_URL__c)
    ) {
      return mapping.Document_Header_URL__c.trim();
    }

    String brochureMode = mapping.Brochure_Attachment_Mode__c;
    if (
      String.isBlank(brochureMode) ||
      brochureMode == BWM_MessagingConstants.BROCHURE_ATTACH_NONE
    ) {
      // Include_Brochure without explicit mode: prefer department, else corporate.
      brochureMode = BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT;
    }

    return BWM_BrochureService.resolveBrochureUrlForSend(
      settings,
      record,
      brochureMode
    );
  }

  /**
   * @description Campaign finalize: scrub DOCUMENT fileName and bodyVariables 4/5/6.
   * @param settings Messaging settings.
   * @param record Record being messaged.
   * @param payloadJson Serialized journey payload.
   * @param mapping Template mapping for brochure mode.
   * @return Updated payload JSON.
   */
  public static String finalizeCampaignPayload(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    String payloadJson,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (String.isBlank(payloadJson)) {
      return payloadJson;
    }

    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(
      payloadJson
    );
    Map<String, Object> content = (Map<String, Object>) root.get('content');
    if (content == null) {
      return payloadJson;
    }
    Map<String, Object> data = (Map<String, Object>) content.get('data');
    if (data == null) {
      return payloadJson;
    }

    content.put(
      'data',
      applyDynamicDocumentHeaders(settings, record, data, mapping)
    );
    return JSON.serialize(root);
  }

  /**
   * @description Rewrites WhatsApp DOCUMENT header URLs in a journey data payload to the
   *              department or corporate brochure URL (sandbox-safe). Used for Campaign
   *              Journey / WhatsApp when Payload_JSON has a static PDF link. Also scrubs
   *              literal bodyVariables 4/5/6 and sets a clean fileName.
   * @param settings Messaging settings.
   * @param record Record being messaged.
   * @param dataPayload Deserialized journey content.data map.
   * @param mapping Optional template mapping for brochure mode; may be null.
   * @return Updated data payload map.
   */
  public static Map<String, Object> applyDynamicDocumentHeaders(
    BWM_Messaging_Settings__mdt settings,
    SObject record,
    Map<String, Object> dataPayload,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (dataPayload == null || dataPayload.isEmpty()) {
      return dataPayload;
    }

    Map<String, Object> journeyPayload = (Map<String, Object>) dataPayload.get(
      'journeypayload'
    );
    if (journeyPayload == null) {
      return dataPayload;
    }
    Map<String, Object> nodes = (Map<String, Object>) journeyPayload.get('nodes');
    if (nodes == null || nodes.isEmpty()) {
      return dataPayload;
    }

    String brochureMode = mapping == null
      ? null
      : mapping.Brochure_Attachment_Mode__c;
    if (
      String.isBlank(brochureMode) ||
      brochureMode == BWM_MessagingConstants.BROCHURE_ATTACH_NONE
    ) {
      brochureMode = BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT;
    }

    String brochureUrl = BWM_BrochureService.resolveBrochureUrlForSend(
      settings,
      record,
      brochureMode
    );

    for (String nodeKey : nodes.keySet()) {
      Map<String, Object> node = (Map<String, Object>) nodes.get(nodeKey);
      if (node == null) {
        continue;
      }
      if (String.valueOf(node.get('templateType')) != 'WHATSAPP') {
        continue;
      }
      Map<String, Object> data = (Map<String, Object>) node.get('data');
      if (data == null) {
        continue;
      }

      // Always scrub literal 4/5/6 body placeholders on campaign finalize.
      fixCampaignBodyVariablePlaceholders(record, data, mapping);

      if (String.isBlank(brochureUrl)) {
        continue;
      }

      Boolean hasDocumentHeader =
        String.valueOf(data.get('headerFormat')) ==
        BWM_MessagingConstants.WHATSAPP_HEADER_DOCUMENT;
      List<Object> headerVariables = data.get('headerVariables') instanceof List<Object>
        ? (List<Object>) data.get('headerVariables')
        : null;
      if (!hasDocumentHeader && (headerVariables == null || headerVariables.isEmpty())) {
        // Mapping says brochure required even if Payload_JSON omitted header.
        if (
          mapping != null &&
          (mapping.Include_Brochure_Header__c == true ||
            mapping.Brochure_Attachment_Mode__c ==
              BWM_MessagingConstants.BROCHURE_ATTACH_CORPORATE ||
            mapping.Brochure_Attachment_Mode__c ==
              BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT)
        ) {
          hasDocumentHeader = true;
        } else {
          continue;
        }
      }

      data.put('headerFormat', BWM_MessagingConstants.WHATSAPP_HEADER_DOCUMENT);
      String cleanFileName = resolveDocumentFileName(
        record,
        brochureUrl,
        brochureMode
      );
      Map<String, Object> headerVariable = new Map<String, Object>{
        'index' => 1,
        'type' => 'static',
        'value' => brochureUrl,
        'format' => 'document'
      };
      if (String.isNotBlank(cleanFileName)) {
        headerVariable.put('fileName', cleanFileName);
      }
      data.put('headerVariables', new List<Object>{ headerVariable });
    }

    return dataPayload;
  }

  /**
   * @description Replaces literal 4/5/6 WhatsApp bodyVariables with corporate
   *              secondary contact defaults (does not invent extra slots).
   * @param whatsAppData WhatsApp node data map containing bodyVariables.
   */
  private static void fixCampaignBodyVariablePlaceholders(
    SObject record,
    Map<String, Object> whatsAppData,
    BWM_Template_Mapping__mdt mapping
  ) {
    if (whatsAppData == null || BWM_CampaignJourneyParamService.isDualCorporateSupportPhoneTemplate(mapping) || BWM_CampaignJourneyParamService.isDealerSalesAssignTemplate(mapping) || BWM_CampaignJourneyParamService.isProspectEnqDeptOwnerContactTemplate(mapping)) {
      return;
    }

    List<Object> bodyVariables = whatsAppData.get('bodyVariables') instanceof List<Object>
      ? (List<Object>) whatsAppData.get('bodyVariables')
      : null;
    if (bodyVariables == null || bodyVariables.isEmpty()) {
      return;
    }

    for (Object rawItem : bodyVariables) {
      if (!(rawItem instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> item = (Map<String, Object>) rawItem;
      Integer oneBasedIndex = toIntegerIndex(item.get('index'));
      if (oneBasedIndex == null || oneBasedIndex < 4 || oneBasedIndex > 6) {
        continue;
      }
      String value = item.get('value') == null
        ? ''
        : String.valueOf(item.get('value')).trim();
      if (!isMissingBodyVariableValue(value, oneBasedIndex)) {
        continue;
      }
      if (oneBasedIndex == 4) {
        item.put(
          'value',
          BWM_CampaignJourneyParamService.resolveSecondaryContactName(record)
        );
      } else if (oneBasedIndex == 5) {
        item.put(
          'value',
          BWM_CampaignJourneyParamService.resolveSecondaryContactPhone(record)
        );
      } else {
        item.put(
          'value',
          BWM_CampaignJourneyParamService.resolveSecondaryContactEmail(record)
        );
      }
    }
  }

  private static Integer toIntegerIndex(Object rawIndex) {
    if (rawIndex == null) {
      return null;
    }
    if (rawIndex instanceof Integer) {
      return (Integer) rawIndex;
    }
    if (rawIndex instanceof Long) {
      return Integer.valueOf(String.valueOf(rawIndex));
    }
    if (rawIndex instanceof Decimal) {
      return ((Decimal) rawIndex).intValue();
    }
    String asText = String.valueOf(rawIndex).trim();
    if (String.isBlank(asText) || !Pattern.matches('^[0-9]+$', asText)) {
      return null;
    }
    return Integer.valueOf(asText);
  }

  private static Boolean isMissingBodyVariableValue(
    String value,
    Integer oneBasedIndex
  ) {
    if (value == null) {
      return false;
    }
    String trimmed = value.trim();
    if (trimmed == String.valueOf(oneBasedIndex)) {
      return true;
    }
    return trimmed == '{{4}}' ||
      trimmed == '{{5}}' ||
      trimmed == '{{6}}' ||
      trimmed.equalsIgnoreCase('NA');
  }

  private static String resolveCorporateBrochureUrl(
    BWM_Messaging_Settings__mdt settings
  ) {
    return BWM_BrochureService.resolveCorporateWhatsAppUrl(settings);
  }

  private static String resolveBrochureHeaderValue(
    BWM_Messaging_Settings__mdt settings,
    SObject record
  ) {
    return BWM_BrochureService.resolveBrochureUrlForSend(
      settings,
      record,
      BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT
    );
  }

  private static Boolean isValidWhatsAppDocumentUrl(String url) {
    return BWM_BrochureService.isValidWhatsAppDocumentUrl(url);
  }

  private static String resolveDocumentFileName(
    SObject record,
    String documentUrl
  ) {
    return resolveDocumentFileName(record, documentUrl, null);
  }

  private static String resolveDocumentFileName(
    SObject record,
    String documentUrl,
    String brochureMode
  ) {
    // Corporate brochure attachment must always show as "corporate brochure.pdf".
    if (
      brochureMode == BWM_MessagingConstants.BROCHURE_ATTACH_CORPORATE ||
      BWM_BrochureService.isCorporateBrochureUrl(documentUrl)
    ) {
      return 'corporate brochure.pdf';
    }

    // Prefer a clean name from the PDF URL (crash_barrier(2).pdf → crash barrier.pdf).
    String fromUrl = sanitizeDocumentFileName(extractFileNameFromUrl(documentUrl));
    if (String.isNotBlank(fromUrl)) {
      return fromUrl;
    }

    String departmentName = BWM_FieldValueResolver.resolveDepartmentName(record);
    if (String.isNotBlank(departmentName)) {
      String slug = departmentName.trim().toLowerCase();
      slug = slug.replaceAll('[0-9]', '');
      slug = slug.replaceAll('[^a-z\\s]+', ' ');
      slug = slug.replaceAll('\\s+', ' ').trim();
      if (String.isNotBlank(slug)) {
        return slug + '.pdf';
      }
    }

    return 'brochure.pdf';
  }

  private static String extractFileNameFromUrl(String documentUrl) {
    if (String.isBlank(documentUrl)) {
      return null;
    }

    String trimmed = documentUrl.trim();
    Integer queryIndex = trimmed.indexOf('?');
    if (queryIndex >= 0) {
      trimmed = trimmed.substring(0, queryIndex);
    }

    Integer slashIndex = trimmed.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex < trimmed.length() - 1) {
      return trimmed.substring(slashIndex + 1);
    }

    return trimmed;
  }

  /**
   * @description Cleans WhatsApp document file names: crash_barrier(2).pdf → crash barrier.pdf.
   * @param rawFileName File name from URL or department slug.
   * @return Sanitized fileName ending in .pdf, or null when blank.
   */
  private static String sanitizeDocumentFileName(String rawFileName) {
    if (String.isBlank(rawFileName)) {
      return null;
    }

    String fileName = rawFileName.trim();
    String extension = '.pdf';
    Integer dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0) {
      extension = fileName.substring(dotIndex).toLowerCase();
      fileName = fileName.substring(0, dotIndex);
    }

    // Remove copy suffixes: (2), (3), _2, -2, trailing digits.
    fileName = fileName.replaceAll('(?i)\\(\\d+\\)', '');
    fileName = fileName.replaceAll('[_-]\\d+$', '');
    fileName = fileName.replaceAll('[0-9]', '');
    fileName = fileName.replaceAll('[()]', '');
    // Use spaces instead of underscores/hyphens in the display fileName.
    fileName = fileName.replaceAll('[_\\-]+', ' ');
    fileName = fileName.replaceAll('[^a-zA-Z\\s]+', ' ');
    fileName = fileName.replaceAll('\\s+', ' ').trim();
    fileName = fileName.toLowerCase();

    if (String.isBlank(fileName)) {
      return 'brochure' + extension;
    }

    if (extension != '.pdf') {
      extension = '.pdf';
    }

    return fileName + extension;
  }

  /**
   * @description Builds a direct WhatsApp campaign payload (channel WhatsApp + templatepayload)
   *              for Send WhatsApp Campaign — not Journey.
   */
  public static String buildCampaignDirectWhatsAppPayload(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    String whatsAppTemplateName,
    Map<String, Object> templateMeta,
    SObject record,
    String phoneNumber
  ) {
    Integer variableCount = countCampaignBodyVariables(templateMeta);
    List<String> params = resolveCampaignDirectParams(
      mapping,
      templateMeta,
      record,
      variableCount
    );

    List<Object> components = new List<Object>();
    Map<String, Object> headerComponent = buildCampaignDirectHeaderComponent(
      settings,
      mapping,
      templateMeta,
      record
    );
    if (headerComponent != null) {
      components.add(headerComponent);
    }
    if (!params.isEmpty()) {
      components.add(buildCampaignDirectBodyComponent(params));
    }

    String callbackData = String.valueOf(record.Id);
    Map<String, Object> dataContent = new Map<String, Object>{
      'templatepayload' => new Map<String, Object>{
        'messaging_product' => 'whatsapp',
        'recipient_type' => 'individual',
        'type' => 'template',
        'template' => new Map<String, Object>{
          'name' => whatsAppTemplateName,
          'language' => new Map<String, Object>{
            'code' => resolveCampaignTemplateLanguage(templateMeta)
          },
          'components' => components
        }
      },
      'biz_opaque_callback_data' => callbackData
    };
    applyCampaignDirectWebhookSettings(dataContent, settings);

    Map<String, Object> payload = new Map<String, Object>{
      'channel' => BWM_MessagingConstants.CHANNEL_WHATSAPP,
      'to' => new List<String>{ phoneNumber },
      'content' => new Map<String, Object>{ 'data' => dataContent }
    };

    if (String.isNotBlank(settings.WhatsApp_From__c)) {
      payload.put('from', settings.WhatsApp_From__c.trim());
    }

    return JSON.serialize(payload);
  }

  private static List<String> resolveCampaignDirectParams(
    BWM_Template_Mapping__mdt mapping,
    Map<String, Object> templateMeta,
    SObject record,
    Integer variableCount
  ) {
    if (variableCount <= 0) {
      return new List<String>();
    }

    List<String> params;
    if (mapping != null) {
      params = BWM_FieldValueResolver.resolveParamsForRecord(record, mapping);
      params = BWM_CampaignJourneyParamService.applyCampaignContactParamFixes(
        record,
        params,
        mapping
      );
    } else {
      params = buildDefaultCampaignDirectParams(record, variableCount);
      return params;
    }

    return trimCampaignParamsToCount(params, variableCount);
  }

  private static List<String> buildDefaultCampaignDirectParams(
    SObject record,
    Integer variableCount
  ) {
    String companyName = BWM_FieldValueResolver.resolveRecord(record, 'Company');
    if (String.isBlank(companyName)) {
      companyName = BWM_FieldValueResolver.resolveRecord(record, 'Company_Name__c');
    }
    if (String.isBlank(companyName)) {
      companyName = BWM_FieldValueResolver.resolveRecord(record, 'Account.Name');
    }

    List<String> defaults = new List<String>{
      BWM_FieldValueResolver.resolveRecord(record, 'Name'),
      companyName,
      BWM_FieldValueResolver.resolveRecord(record, 'Product_Category__c'),
      BWM_FieldValueResolver.resolveDepartmentName(record),
      BWM_FieldValueResolver.resolveRecord(record, 'Owner.Name'),
      BWM_FieldValueResolver.resolveRecord(record, 'Owner.Phone'),
      BWM_FieldValueResolver.resolveRecord(record, 'Owner.Email'),
      companyName
    };

    List<String> params = new List<String>();
    for (Integer index = 0; index < variableCount; index++) {
      String value = index < defaults.size() ? defaults[index] : '';
      params.add(String.isNotBlank(value) ? value.trim() : 'NA');
    }
    return params;
  }

  private static List<String> trimCampaignParamsToCount(
    List<String> params,
    Integer variableCount
  ) {
    List<String> trimmed = new List<String>();
    for (Integer index = 0; index < variableCount; index++) {
      String value = index < params.size() ? params[index] : '';
      trimmed.add(String.isNotBlank(value) ? value.trim() : 'NA');
    }
    return trimmed;
  }

  private static Map<String, Object> buildCampaignDirectHeaderComponent(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Map<String, Object> templateMeta,
    SObject record
  ) {
    if (mapping != null && mapping.Include_Brochure_Header__c == true) {
      String brochureUrl = resolveDocumentHeaderValue(settings, mapping, record);
      if (String.isNotBlank(brochureUrl)) {
        return new Map<String, Object>{
          'type' => 'header',
          'parameters' => new List<Object>{
            new Map<String, Object>{
              'type' => 'document',
              'document' => new Map<String, Object>{ 'link' => brochureUrl }
            }
          }
        };
      }
    }

    Map<String, Object> content = getCampaignTemplateContent(templateMeta);
    Map<String, Object> header = content == null
      ? null
      : (Map<String, Object>) content.get('header');
    if (header == null) {
      return null;
    }

    String headerType = String.valueOf(header.get('type'));
    if (headerType == 'DOCUMENT') {
      String brochureMode = mapping == null
        ? BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT
        : mapping.Brochure_Attachment_Mode__c;
      if (
        String.isBlank(brochureMode) ||
        brochureMode == BWM_MessagingConstants.BROCHURE_ATTACH_NONE
      ) {
        brochureMode = BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT;
      }
      String brochureUrl = BWM_BrochureService.resolveBrochureUrlForSend(
        settings,
        record,
        brochureMode
      );
      if (String.isBlank(brochureUrl)) {
        return null;
      }
      return new Map<String, Object>{
        'type' => 'header',
        'parameters' => new List<Object>{
          new Map<String, Object>{
            'type' => 'document',
            'document' => new Map<String, Object>{ 'link' => brochureUrl }
          }
        }
      };
    }

    if (headerType == 'TEXT') {
      String headerText = header.containsKey('text')
        ? String.valueOf(header.get('text'))
        : BWM_FieldValueResolver.resolveDepartmentName(record);
      return new Map<String, Object>{
        'type' => 'header',
        'parameters' => new List<Object>{
          new Map<String, Object>{
            'type' => 'text',
            'text' => String.isNotBlank(headerText) ? headerText.trim() : 'NA'
          }
        }
      };
    }

    return null;
  }

  private static Map<String, Object> buildCampaignDirectBodyComponent(
    List<String> params
  ) {
    List<Object> parameters = new List<Object>();
    for (String value : params) {
      parameters.add(
        new Map<String, Object>{
          'type' => 'text',
          'text' => String.isBlank(value) ? ' ' : value.trim()
        }
      );
    }

    return new Map<String, Object>{
      'type' => 'body',
      'parameters' => parameters
    };
  }

  private static void applyCampaignDirectWebhookSettings(
    Map<String, Object> dataContent,
    BWM_Messaging_Settings__mdt settings
  ) {
    if (settings == null || String.isBlank(settings.Webhook_Callback_URL__c)) {
      return;
    }

    String webhookUrl = settings.Webhook_Callback_URL__c.trim();
    dataContent.put('webhookUrl', webhookUrl);
    dataContent.put('callbackUrl', webhookUrl);
  }

  private static String resolveCampaignTemplateLanguage(
    Map<String, Object> templateMeta
  ) {
    if (templateMeta != null && templateMeta.containsKey('language')) {
      String templateLanguage = String.valueOf(templateMeta.get('language'));
      if (String.isNotBlank(templateLanguage)) {
        return templateLanguage.trim();
      }
    }
    return 'en';
  }

  private static Integer countCampaignBodyVariables(Map<String, Object> templateMeta) {
    Map<String, Object> content = getCampaignTemplateContent(templateMeta);
    if (content != null && content.containsKey('body')) {
      Integer fromBody = countCampaignVariablesInText(String.valueOf(content.get('body')));
      if (fromBody > 0) {
        return fromBody;
      }
    }

    if (templateMeta != null && templateMeta.get('components') instanceof List<Object>) {
      for (Object componentObject : (List<Object>) templateMeta.get('components')) {
        if (!(componentObject instanceof Map<String, Object>)) {
          continue;
        }
        Map<String, Object> componentMap = (Map<String, Object>) componentObject;
        if (String.valueOf(componentMap.get('type')).toUpperCase() != 'BODY') {
          continue;
        }
        Integer fromComponent = countCampaignVariablesInText(
          String.valueOf(componentMap.get('text'))
        );
        if (fromComponent > 0) {
          return fromComponent;
        }
      }
    }

    return 0;
  }

  private static Integer countCampaignVariablesInText(String body) {
    if (String.isBlank(body)) {
      return 0;
    }

    Integer maxIndex = 0;
    Matcher matcher = Pattern.compile('\\{\\{(\\d+)\\}\\}').matcher(body);
    while (matcher.find()) {
      Integer currentIndex = Integer.valueOf(matcher.group(1));
      if (currentIndex > maxIndex) {
        maxIndex = currentIndex;
      }
    }
    return maxIndex;
  }

  private static Map<String, Object> getCampaignTemplateContent(
    Map<String, Object> templateMeta
  ) {
    if (templateMeta == null || !templateMeta.containsKey('content')) {
      return null;
    }
    return (Map<String, Object>) templateMeta.get('content');
  }

  public static String buildWhatsAppPayload(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Lead leadRecord,
    String phoneNumber
  ) {
    return buildJourneyPayloadForRecord(settings, mapping, leadRecord, phoneNumber);
  }

  public static String buildWhatsAppPayloadForRecord(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    String phoneNumber
  ) {
    return buildJourneyPayloadForRecord(settings, mapping, record, phoneNumber);
  }

  public static String buildRcsPayload(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Lead leadRecord,
    String phoneNumber
  ) {
    return buildJourneyPayloadForRecord(settings, mapping, leadRecord, phoneNumber);
  }

  public static String buildRcsPayloadForRecord(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    String phoneNumber
  ) {
    return buildJourneyPayloadForRecord(settings, mapping, record, phoneNumber);
  }

  public static String buildSmsPayloadForRecord(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    String phoneNumber
  ) {
    return buildJourneyPayloadForRecord(settings, mapping, record, phoneNumber);
  }
}