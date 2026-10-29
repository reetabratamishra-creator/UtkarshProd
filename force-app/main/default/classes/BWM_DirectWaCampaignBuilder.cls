/**
 * @description Builds direct WhatsApp templatepayload payloads for Send WhatsApp Campaign.
 */
public without sharing class BWM_DirectWaCampaignBuilder {
  public static String buildPayload(
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

    return BWM_JourneyDefinitionService.applyScheduledDateTime(
      JSON.serialize(payload),
      BWM_CampaignScheduleContext.scheduledDateTime
    );
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
      String brochureUrl = resolveMappingDocumentHeader(settings, mapping, record);
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


  private static String resolveMappingDocumentHeader(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (
      mapping != null &&
      BWM_BrochureService.isValidWhatsAppDocumentUrl(mapping.Document_Header_URL__c) &&
      !BWM_BrochureService.isSandboxOrInaccessibleUrl(mapping.Document_Header_URL__c)
    ) {
      return mapping.Document_Header_URL__c.trim();
    }

    if (mapping == null) {
      return null;
    }

    String brochureMode = mapping.Brochure_Attachment_Mode__c;
    if (
      String.isBlank(brochureMode) ||
      brochureMode == BWM_MessagingConstants.BROCHURE_ATTACH_NONE
    ) {
      brochureMode = BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT;
    }

    return BWM_BrochureService.resolveBrochureUrlForSend(
      settings,
      record,
      brochureMode
    );
  }
}