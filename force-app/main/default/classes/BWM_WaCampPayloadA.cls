/**
 * @description Builds direct WhatsApp templatepayload payloads for Send WhatsApp Campaign.
 *              Components are derived from the selected template JSON so parameter counts
 *              and formats match the approved Meta template (avoids error 132012).
 */
public without sharing class BWM_WaCampPayloadA {
  private static final String VIDEO_PORTAL_BASE =
    'https://portal.bluewavesmedia.in/WhatsAppMedia/Template/Video/Utkarsh/';

  private class TemplateDefinition {
    public String headerFormat;
    public String contentHeaderFormat;
    public String headerText;
    public String headerMediaUrl;
    public String bodyText;
    public List<Map<String, Object>> buttons = new List<Map<String, Object>>();
  }

  public static String buildPayload(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    String whatsAppTemplateName,
    Map<String, Object> templateMeta,
    SObject record,
    String phoneNumber
  ) {
    TemplateDefinition definition = parseTemplateDefinition(templateMeta);
    Integer bodyVariableCount = countCampaignVariablesInText(definition.bodyText);
    Integer headerVariableCount = countCampaignVariablesInText(definition.headerText);
    Integer buttonVariableCount = countButtonUrlVariables(definition.buttons);
    Integer totalVariableCount = Math.max(
      bodyVariableCount,
      Math.max(headerVariableCount, buttonVariableCount)
    );

    List<String> params = resolveCampaignDirectParams(
      mapping,
      record,
      totalVariableCount
    );

    List<Object> components = buildComponentsFromTemplateDefinition(
      settings,
      mapping,
      templateMeta,
      definition,
      record,
      params,
      bodyVariableCount,
      headerVariableCount
    );

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

  private static List<Object> buildComponentsFromTemplateDefinition(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Map<String, Object> templateMeta,
    TemplateDefinition definition,
    SObject record,
    List<String> params,
    Integer bodyVariableCount,
    Integer headerVariableCount
  ) {
    List<Object> components = new List<Object>();

    Map<String, Object> headerComponent = buildHeaderComponentFromDefinition(
      settings,
      mapping,
      templateMeta,
      definition,
      record,
      params,
      headerVariableCount
    );
    if (headerComponent != null) {
      components.add(headerComponent);
    }

    if (bodyVariableCount > 0) {
      components.add(
        buildBodyComponent(trimCampaignParamsToCount(params, bodyVariableCount))
      );
    }

    components.addAll(buildButtonComponents(definition.buttons, params));

    return components;
  }

  private static TemplateDefinition parseTemplateDefinition(
    Map<String, Object> templateMeta
  ) {
    TemplateDefinition definition = new TemplateDefinition();

    Map<String, Object> content = getCampaignTemplateContent(templateMeta);
    if (content != null) {
      if (content.containsKey('body')) {
        definition.bodyText = String.valueOf(content.get('body'));
      }
      if (content.get('header') instanceof Map<String, Object>) {
        Map<String, Object> header = (Map<String, Object>) content.get('header');
        definition.contentHeaderFormat = normalizeHeaderFormat(
          header.containsKey('format')
            ? String.valueOf(header.get('format'))
            : String.valueOf(header.get('type'))
        );
        definition.headerFormat = definition.contentHeaderFormat;
        if (header.containsKey('text')) {
          definition.headerText = String.valueOf(header.get('text'));
        }
        definition.headerMediaUrl = resolveHeaderMediaUrlFromMap(header);
      }
    }

    if (templateMeta != null && templateMeta.get('components') instanceof List<Object>) {
      for (Object componentObject : (List<Object>) templateMeta.get('components')) {
        if (!(componentObject instanceof Map<String, Object>)) {
          continue;
        }
        Map<String, Object> componentMap = (Map<String, Object>) componentObject;
        String componentType = String.valueOf(componentMap.get('type')).toUpperCase();

        if (componentType == 'HEADER') {
          if (String.isBlank(definition.headerFormat)) {
            definition.headerFormat = normalizeHeaderFormat(
              String.valueOf(componentMap.get('format'))
            );
          }
          if (componentMap.containsKey('text')) {
            definition.headerText = String.valueOf(componentMap.get('text'));
          }
          if (String.isBlank(definition.headerMediaUrl)) {
            definition.headerMediaUrl = resolveHeaderMediaUrlFromMap(componentMap);
          }
        } else if (componentType == 'BODY' && String.isBlank(definition.bodyText)) {
          definition.bodyText = String.valueOf(componentMap.get('text'));
        } else if (componentType == 'BUTTONS' && componentMap.get('buttons') instanceof List<Object>) {
          addTemplateButtons(definition, (List<Object>) componentMap.get('buttons'));
        }
      }
    }

    if (content != null && content.get('buttons') instanceof List<Object>) {
      addTemplateButtons(definition, (List<Object>) content.get('buttons'));
    }

    return definition;
  }

  private static void addTemplateButtons(
    TemplateDefinition definition,
    List<Object> buttonObjects
  ) {
    for (Object buttonObject : buttonObjects) {
      if (buttonObject instanceof Map<String, Object>) {
        definition.buttons.add((Map<String, Object>) buttonObject);
      }
    }
  }

  private static String normalizeHeaderFormat(String rawFormat) {
    if (String.isBlank(rawFormat)) {
      return null;
    }
    return rawFormat.trim().toUpperCase();
  }

  private static Map<String, Object> buildHeaderComponentFromDefinition(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Map<String, Object> templateMeta,
    TemplateDefinition definition,
    SObject record,
    List<String> params,
    Integer headerVariableCount
  ) {
    String headerFormat = resolveEffectiveHeaderFormat(definition);
    if (String.isBlank(headerFormat)) {
      return null;
    }

    if (headerFormat == 'DOCUMENT') {
      String documentLink = resolveDocumentHeaderLink(settings, mapping, record);
      if (String.isBlank(documentLink)) {
        documentLink = definition.headerMediaUrl;
      }
      if (String.isBlank(documentLink) || !isPdfUrl(documentLink)) {
        return null;
      }
      documentLink = normalizeMediaUrl(documentLink);
      Map<String, Object> documentPayload = new Map<String, Object>{
        'link' => documentLink
      };
      String brochureMode = mapping == null
        ? BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT
        : mapping.Brochure_Attachment_Mode__c;
      String fileName = resolveDocumentFileName(record, documentLink, brochureMode);
      if (String.isNotBlank(fileName)) {
        documentPayload.put('filename', fileName);
      }
      return new Map<String, Object>{
        'type' => 'header',
        'parameters' => new List<Object>{
          new Map<String, Object>{
            'type' => 'document',
            'document' => documentPayload
          }
        }
      };
    }

    if (headerFormat == 'IMAGE') {
      String imageLink = resolveMediaHeaderLink(
        settings,
        mapping,
        templateMeta,
        definition,
        record,
        'IMAGE'
      );
      if (String.isBlank(imageLink)) {
        return null;
      }
      return new Map<String, Object>{
        'type' => 'header',
        'parameters' => new List<Object>{
          new Map<String, Object>{
            'type' => 'image',
            'image' => new Map<String, Object>{ 'link' => normalizeMediaUrl(imageLink) }
          }
        }
      };
    }

    if (headerFormat == 'VIDEO') {
      String videoLink = resolveVideoHeaderLink(
        settings,
        mapping,
        templateMeta,
        definition,
        record
      );
      if (String.isBlank(videoLink)) {
        return null;
      }
      return new Map<String, Object>{
        'type' => 'header',
        'parameters' => new List<Object>{
          new Map<String, Object>{
            'type' => 'video',
            'video' => new Map<String, Object>{ 'link' => normalizeMediaUrl(videoLink) }
          }
        }
      };
    }

    if (headerFormat == 'TEXT' && headerVariableCount > 0) {
      List<String> headerParams = trimCampaignParamsToCount(
        resolveHeaderTextParams(mapping, record, params, headerVariableCount),
        headerVariableCount
      );
      List<Object> parameters = new List<Object>();
      for (String value : headerParams) {
        parameters.add(buildTextParameter(value));
      }
      return new Map<String, Object>{
        'type' => 'header',
        'parameters' => parameters
      };
    }

    return null;
  }

  private static String resolveEffectiveHeaderFormat(TemplateDefinition definition) {
    if (definition == null) {
      return null;
    }
    if (String.isNotBlank(definition.contentHeaderFormat)) {
      return definition.contentHeaderFormat;
    }
    return definition.headerFormat;
  }

  private static String resolveHeaderMediaUrlFromMap(Map<String, Object> headerMap) {
    if (headerMap == null) {
      return null;
    }

    for (String key : new List<String>{
      'link',
      'url',
      'media_url',
      'mediaUrl',
      'media_link',
      'mediaLink'
    }) {
      if (headerMap.containsKey(key) && String.isNotBlank(String.valueOf(headerMap.get(key)))) {
        return String.valueOf(headerMap.get(key)).trim();
      }
    }

    if (headerMap.get('example') instanceof Map<String, Object>) {
      Map<String, Object> example = (Map<String, Object>) headerMap.get('example');
      if (example.get('header_url') instanceof List<Object>) {
        List<Object> urls = (List<Object>) example.get('header_url');
        if (!urls.isEmpty() && urls[0] != null) {
          return String.valueOf(urls[0]).trim();
        }
      }
      if (example.get('header_handle') instanceof List<Object>) {
        List<Object> handles = (List<Object>) example.get('header_handle');
        if (!handles.isEmpty() && handles[0] != null) {
          String handle = String.valueOf(handles[0]).trim();
          if (handle.startsWith('http')) {
            return handle;
          }
        }
      }
    }

    return null;
  }

  private static String resolveVideoHeaderLink(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Map<String, Object> templateMeta,
    TemplateDefinition definition,
    SObject record
  ) {
    if (
      String.isNotBlank(definition.headerMediaUrl) &&
      isVideoUrl(definition.headerMediaUrl)
    ) {
      return definition.headerMediaUrl.trim();
    }

    Map<String, Object> content = getCampaignTemplateContent(templateMeta);
    if (content != null && content.get('header') instanceof Map<String, Object>) {
      String contentMediaUrl = resolveHeaderMediaUrlFromMap(
        (Map<String, Object>) content.get('header')
      );
      if (String.isNotBlank(contentMediaUrl) && isVideoUrl(contentMediaUrl)) {
        return contentMediaUrl.trim();
      }
    }

    String brochurePdfUrl = resolveDocumentHeaderLink(settings, mapping, record);
    for (String slug : buildVideoSlugCandidates(definition.bodyText, record, brochurePdfUrl)) {
      String candidate = VIDEO_PORTAL_BASE + slug + '.mp4';
      if (String.isNotBlank(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  private static List<String> buildVideoSlugCandidates(
    String templateBody,
    SObject record,
    String brochurePdfUrl
  ) {
    Set<String> slugs = new Set<String>();

    for (String slug : inferVideoSlugsFromTemplateBody(templateBody)) {
      slugs.add(slug);
    }

    for (String slug : buildDepartmentVideoSlugs(BWM_FieldValueResolver.resolveDepartmentName(record))) {
      slugs.add(slug);
    }

    for (String slug : buildSlugsFromPdfBasename(brochurePdfUrl)) {
      slugs.add(slug);
    }

    return new List<String>(slugs);
  }

  private static List<String> inferVideoSlugsFromTemplateBody(String templateBody) {
    List<String> slugs = new List<String>();
    if (String.isBlank(templateBody)) {
      return slugs;
    }

    String lowerBody = templateBody.toLowerCase();
    if (lowerBody.contains('crash barrier') || lowerBody.contains('crash-tested')) {
      slugs.add('crash_barrier');
      slugs.add('Crash_Barrier');
    }
    if (lowerBody.contains('high mast') || lowerBody.contains('polygonal')) {
      slugs.add('high_mast');
      slugs.add('High_Mast');
    }
    if (lowerBody.contains('pvc pipe')) {
      slugs.add('pvc_pipes_and_fittings');
      slugs.add('PVC_Pipes_and_Fittings');
    }
    if (lowerBody.contains('solar')) {
      slugs.add('solar');
      slugs.add('Solar');
    }

    return slugs;
  }

  private static List<String> buildDepartmentVideoSlugs(String departmentName) {
    List<String> slugs = new List<String>();
    if (String.isBlank(departmentName)) {
      return slugs;
    }

    String trimmed = departmentName.trim();
    slugs.add(
      trimmed.toLowerCase().replaceAll('[^a-z0-9]+', '_').replaceAll('_+', '_').replaceAll('^_+|_+$', '')
    );

    String titleSlug = '';
    for (String part : trimmed.split('\\s+')) {
      if (String.isBlank(part)) {
        continue;
      }
      titleSlug += part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase() + '_';
    }
    titleSlug = titleSlug.replaceAll('_+', '_').replaceAll('_+$', '');
    if (String.isNotBlank(titleSlug)) {
      slugs.add(titleSlug);
    }

    return slugs;
  }

  private static List<String> buildSlugsFromPdfBasename(String pdfUrl) {
    List<String> slugs = new List<String>();
    String fileName = extractFileNameFromUrl(pdfUrl);
    if (String.isBlank(fileName)) {
      return slugs;
    }

    Integer dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0) {
      fileName = fileName.substring(0, dotIndex);
    }

    fileName = fileName.replaceAll('(?i)\\(\\d+\\)', '').replaceAll('[_-]\\d+$', '');
    if (String.isBlank(fileName)) {
      return slugs;
    }

    slugs.add(fileName);
    slugs.add(fileName.toLowerCase().replaceAll('[^a-z0-9]+', '_').replaceAll('_+', '_').replaceAll('^_+|_+$', ''));
    return slugs;
  }

  private static String resolveMediaHeaderLink(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Map<String, Object> templateMeta,
    TemplateDefinition definition,
    SObject record,
    String expectedFormat
  ) {
    if (
      String.isNotBlank(definition.headerMediaUrl) &&
      mediaUrlMatchesFormat(definition.headerMediaUrl, expectedFormat)
    ) {
      return definition.headerMediaUrl.trim();
    }

    Map<String, Object> content = getCampaignTemplateContent(templateMeta);
    if (content != null && content.get('header') instanceof Map<String, Object>) {
      String contentMediaUrl = resolveHeaderMediaUrlFromMap(
        (Map<String, Object>) content.get('header')
      );
      if (
        String.isNotBlank(contentMediaUrl) &&
        mediaUrlMatchesFormat(contentMediaUrl, expectedFormat)
      ) {
        return contentMediaUrl.trim();
      }
    }

    String brochureUrl = resolveDocumentHeaderLink(settings, mapping, record);
    if (
      String.isNotBlank(brochureUrl) &&
      mediaUrlMatchesFormat(brochureUrl, expectedFormat)
    ) {
      return brochureUrl.trim();
    }

    return null;
  }

  private static Boolean mediaUrlMatchesFormat(String url, String expectedFormat) {
    if (String.isBlank(url) || String.isBlank(expectedFormat)) {
      return false;
    }
    if (expectedFormat == 'DOCUMENT') {
      return isPdfUrl(url);
    }
    if (expectedFormat == 'VIDEO') {
      return isVideoUrl(url);
    }
    if (expectedFormat == 'IMAGE') {
      return isImageUrl(url);
    }
    return false;
  }

  private static Boolean isPdfUrl(String url) {
    return String.isNotBlank(url) && url.trim().toLowerCase().contains('.pdf');
  }

  private static Boolean isVideoUrl(String url) {
    if (String.isBlank(url)) {
      return false;
    }
    String normalized = url.trim().toLowerCase();
    return normalized.contains('.mp4') ||
      normalized.contains('.3gp') ||
      normalized.contains('.3gpp');
  }

  private static Boolean isImageUrl(String url) {
    if (String.isBlank(url)) {
      return false;
    }
    String normalized = url.trim().toLowerCase();
    return normalized.contains('.jpg') ||
      normalized.contains('.jpeg') ||
      normalized.contains('.png') ||
      normalized.contains('.webp');
  }

  private static String normalizeMediaUrl(String url) {
    if (String.isBlank(url)) {
      return url;
    }
    return url.trim().replace('(', '%28').replace(')', '%29');
  }

  private static String resolveDocumentFileName(
    SObject record,
    String documentUrl,
    String brochureMode
  ) {
    if (String.isBlank(documentUrl)) {
      return null;
    }

    if (
      brochureMode == BWM_MessagingConstants.BROCHURE_ATTACH_CORPORATE ||
      BWM_BrochureService.isCorporateBrochureUrl(documentUrl)
    ) {
      return 'corporate_brochure.pdf';
    }

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
        return slug.replace(' ', '_') + '.pdf';
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

    fileName = fileName.replaceAll('(?i)\\(\\d+\\)', '');
    fileName = fileName.replaceAll('[_-]\\d+$', '');
    fileName = fileName.replaceAll('[0-9]', '');
    fileName = fileName.replaceAll('[()]', '');
    fileName = fileName.replaceAll('[_\\-]+', '_');
    fileName = fileName.replaceAll('[^a-zA-Z_\\-]+', '_');
    fileName = fileName.replaceAll('_+', '_');
    fileName = fileName.replaceAll('^_+|_+$', '');
    fileName = fileName.toLowerCase();

    if (String.isBlank(fileName)) {
      return 'brochure' + extension;
    }

    if (extension != '.pdf') {
      extension = '.pdf';
    }

    return fileName + extension;
  }

  private static List<String> resolveHeaderTextParams(
    BWM_Template_Mapping__mdt mapping,
    SObject record,
    List<String> bodyParams,
    Integer headerVariableCount
  ) {
    List<String> headerParams = new List<String>();
    for (Integer index = 0; index < headerVariableCount; index++) {
      String value = null;
      if (
        index == 0 &&
        mapping != null &&
        String.isNotBlank(mapping.WhatsApp_Header_Value_Field__c)
      ) {
        value = BWM_FieldValueResolver.resolveRecord(
          record,
          mapping.WhatsApp_Header_Value_Field__c
        );
      }
      if (String.isBlank(value)) {
        value = BWM_FieldValueResolver.resolveDepartmentName(record);
      }
      if (String.isBlank(value) && bodyParams != null && index < bodyParams.size()) {
        value = bodyParams[index];
      }
      headerParams.add(String.isNotBlank(value) ? value.trim() : 'NA');
    }
    return headerParams;
  }

  private static String resolveDocumentHeaderLink(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    SObject record
  ) {
    if (mapping != null) {
      String mappingUrl = resolveMappingDocumentHeader(settings, mapping, record);
      if (String.isNotBlank(mappingUrl)) {
        return mappingUrl;
      }
    }

    String brochureMode = mapping == null
      ? BWM_MessagingConstants.BROCHURE_ATTACH_DEPARTMENT
      : mapping.Brochure_Attachment_Mode__c;
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

  private static List<Object> buildButtonComponents(
    List<Map<String, Object>> buttons,
    List<String> params
  ) {
    List<Object> components = new List<Object>();
    if (buttons == null || buttons.isEmpty()) {
      return components;
    }

    Integer buttonIndex = 0;
    for (Map<String, Object> button : buttons) {
      String buttonType = String.valueOf(button.get('type')).toUpperCase();
      if (buttonType == 'QUICK_REPLY') {
        String payloadValue = resolveQuickReplyPayload(button);
        components.add(
          new Map<String, Object>{
            'type' => 'button',
            'sub_type' => 'quick_reply',
            'index' => String.valueOf(buttonIndex),
            'parameters' => new List<Object>{
              new Map<String, Object>{
                'type' => 'payload',
                'payload' => String.isNotBlank(payloadValue) ? payloadValue.trim() : 'Reply'
              }
            }
          }
        );
      } else if (buttonType == 'URL') {
        Integer urlVariableCount = countCampaignVariablesInText(
          String.valueOf(button.get('url'))
        );
        if (urlVariableCount > 0) {
          List<String> urlParams = trimCampaignParamsToCount(params, urlVariableCount);
          List<Object> parameters = new List<Object>();
          for (String value : urlParams) {
            parameters.add(buildTextParameter(value));
          }
          components.add(
            new Map<String, Object>{
              'type' => 'button',
              'sub_type' => 'url',
              'index' => String.valueOf(buttonIndex),
              'parameters' => parameters
            }
          );
        }
      }
      buttonIndex++;
    }

    return components;
  }

  private static String resolveQuickReplyPayload(Map<String, Object> button) {
    if (button.containsKey('text') && String.isNotBlank(String.valueOf(button.get('text')))) {
      return String.valueOf(button.get('text')).trim();
    }
    if (button.get('data') instanceof Map<String, Object>) {
      Map<String, Object> data = (Map<String, Object>) button.get('data');
      if (data.containsKey('button_text') && String.isNotBlank(String.valueOf(data.get('button_text')))) {
        return String.valueOf(data.get('button_text')).trim();
      }
    }
    return 'Reply';
  }

  private static Integer countButtonUrlVariables(List<Map<String, Object>> buttons) {
    Integer maxCount = 0;
    if (buttons == null) {
      return maxCount;
    }
    for (Map<String, Object> button : buttons) {
      if (String.valueOf(button.get('type')).toUpperCase() != 'URL') {
        continue;
      }
      Integer count = countCampaignVariablesInText(String.valueOf(button.get('url')));
      if (count > maxCount) {
        maxCount = count;
      }
    }
    return maxCount;
  }

  private static Map<String, Object> buildBodyComponent(List<String> params) {
    List<Object> parameters = new List<Object>();
    for (String value : params) {
      parameters.add(buildTextParameter(value));
    }

    return new Map<String, Object>{
      'type' => 'body',
      'parameters' => parameters
    };
  }

  private static Map<String, Object> buildTextParameter(String value) {
    return new Map<String, Object>{
      'type' => 'text',
      'text' => String.isBlank(value) ? ' ' : value.trim()
    };
  }

  private static List<String> resolveCampaignDirectParams(
    BWM_Template_Mapping__mdt mapping,
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
      return buildDefaultCampaignDirectParams(record, variableCount);
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

    if (mapping == null || mapping.Include_Brochure_Header__c != true) {
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