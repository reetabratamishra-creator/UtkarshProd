/**
 * @description   Builds u_quotation_manual_trigger WhatsApp payload for manual quote
 *                send to customer.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public without sharing class OpportunityQuoteWhatsAppPayloadBuilder {
  private static final String TEMPLATE_NAME = 'u_quotation_manual_trigger';
  private static final String TEMPLATE_LANGUAGE = 'en';
  public static final String WHATSAPP_FROM = '919147100753';
  private static final String FINAL_QUOTE_DOCUMENT_ID_FIELD = 'Final_Quote_Document_ID__c';

  /**
   * @description Creates a public download link for the final quote file when one does not exist yet.
   *              Call before the WhatsApp HTTP callout when this returns true (DML must commit first).
   * @param opportunityRecord Opportunity with Final_Quote_Document_ID__c populated.
   * @return True when a new ContentDistribution was created for the quote file.
   */
  public static Boolean prepareFinalQuotePublicLink(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return false;
    }

    Id contentDocumentId = parsePrimaryContentDocumentId(
      (String) opportunityRecord.get(FINAL_QUOTE_DOCUMENT_ID_FIELD)
    );
    if (contentDocumentId == null) {
      return false;
    }

    ContentVersion versionRecord = queryLatestContentVersion(contentDocumentId);
    if (versionRecord == null) {
      return false;
    }

    if (String.isNotBlank(resolveExistingPublicUrl(versionRecord))) {
      return false;
    }

    return String.isNotBlank(
      BWM_BrochureFileService.ensurePublicDownloadUrl(
        versionRecord.Title,
        versionRecord.Id
      )
    );
  }

  /**
   * @description Builds the WhatsApp JSON payload for manual quote send including template, document, and callbacks.
   * @param settings Messaging settings for webhook and brochure defaults.
   * @param mapping Template mapping used to resolve body parameters.
   * @param opportunityRecord Opportunity providing merge fields and callback Id.
   * @param phoneNumber Recipient phone number for the to list.
   * @return Serialized WhatsApp payload JSON string.
   */
  public static String buildPayload(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Opportunity opportunityRecord,
    String phoneNumber
  ) {
    return buildPayload(
      settings,
      mapping,
      opportunityRecord,
      phoneNumber,
      resolveQuoteDocumentUrl(settings, opportunityRecord)
    );
  }

  /**
   * @description Builds the WhatsApp JSON payload using a pre-resolved document URL.
   * @param settings Messaging settings for webhook and brochure defaults.
   * @param mapping Template mapping used to resolve body parameters.
   * @param opportunityRecord Opportunity providing merge fields and callback Id.
   * @param phoneNumber Recipient phone number for the to list.
   * @param documentLink Public document URL for the WhatsApp header.
   * @return Serialized WhatsApp payload JSON string.
   */
  public static String buildPayload(
    BWM_Messaging_Settings__mdt settings,
    BWM_Template_Mapping__mdt mapping,
    Opportunity opportunityRecord,
    String phoneNumber,
    String documentLink
  ) {
    if (settings == null || mapping == null || opportunityRecord == null) {
      throw new AuraHandledException('Quote WhatsApp payload inputs are incomplete.');
    }
    if (String.isBlank(phoneNumber)) {
      throw new AuraHandledException('Phone number is required.');
    }
    if (String.isBlank(documentLink)) {
      throw new AuraHandledException(
        'Quotation document URL is not available for WhatsApp delivery.'
      );
    }

    List<String> params = BWM_FieldValueResolver.resolveParamsForRecord(
      opportunityRecord,
      mapping
    );
    String documentFileName = resolveQuoteDocumentFileName(opportunityRecord);
    String callbackData = String.valueOf(opportunityRecord.Id);
    Map<String, Object> dataContent = new Map<String, Object>{
      'templatepayload' => buildTemplatePayload(
        params,
        documentLink,
        documentFileName,
        callbackData
      ),
      'biz_opaque_callback_data' => callbackData
    };
    applyWebhookSettings(dataContent, settings);

    Map<String, Object> payload = new Map<String, Object>{
      'channel' => BWM_MessagingConstants.CHANNEL_WHATSAPP,
      'to' => new List<String>{ phoneNumber },
      'content' => new Map<String, Object>{
        'data' => dataContent
      }
    };

    payload.put('from', WHATSAPP_FROM);

    return JSON.serialize(payload);
  }

  /**
   * @description Builds the nested WhatsApp templatepayload map for u_quotation_manual_trigger.
   * @param params Resolved template body parameter values.
   * @param documentLink Document URL used in the header component.
   * @param callbackData Opaque callback data (Opportunity Id).
   * @return Template payload map ready for JSON serialization.
   */
  private static Map<String, Object> buildTemplatePayload(
    List<String> params,
    String documentLink,
    String documentFileName,
    String callbackData
  ) {
    return new Map<String, Object>{
      'messaging_product' => 'whatsapp',
      'recipient_type' => 'individual',
      'type' => 'template',
      'template' => new Map<String, Object>{
        'name' => TEMPLATE_NAME,
        'language' => new Map<String, Object>{ 'code' => TEMPLATE_LANGUAGE },
        'components' => buildTemplateComponents(
          params,
          documentLink,
          documentFileName
        )
      },
      'biz_opaque_callback_data' => callbackData
    };
  }

  /**
   * @description Adds webhookUrl and callbackUrl to payload data when configured in settings.
   * @param dataContent Mutable content.data map receiving webhook keys.
   * @param settings Messaging settings containing Webhook_Callback_URL__c.
   */
  private static void applyWebhookSettings(
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

  /**
   * @description Builds header document, body text parameters, and Yes/No quick-reply button components.
   * @param params Resolved template body parameter values.
   * @param documentLink Document URL for the header component.
   * @return List of WhatsApp template component maps.
   */
  private static List<Object> buildTemplateComponents(
    List<String> params,
    String documentLink,
    String documentFileName
  ) {
    Map<String, Object> documentPayload = new Map<String, Object>{
      'link' => documentLink
    };
    if (String.isNotBlank(documentFileName)) {
      documentPayload.put('filename', documentFileName);
    }

    return new List<Object>{
      new Map<String, Object>{
        'type' => 'header',
        'parameters' => new List<Object>{
          new Map<String, Object>{
            'type' => 'document',
            'document' => documentPayload
          }
        }
      },
      new Map<String, Object>{
        'type' => 'body',
        'parameters' => new List<Object>{
          buildTextParameter(getParam(params, 0)),
          buildTextParameter(getParam(params, 1)),
          buildTextParameter(getParam(params, 2)),
          buildTextParameter(getParam(params, 3))
        }
      },
      buildQuickReplyButton('0', 'Yes'),
      buildQuickReplyButton('1', 'No')
    };
  }

  /**
   * @description Builds a quick-reply button component for the quote template.
   * @param index Button index as a string.
   * @param payloadValue Payload value returned when the button is tapped.
   * @return WhatsApp button component map.
   */
  private static Map<String, Object> buildQuickReplyButton(
    String index,
    String payloadValue
  ) {
    return new Map<String, Object>{
      'type' => 'button',
      'sub_type' => 'quick_reply',
      'index' => index,
      'parameters' => new List<Object>{
        new Map<String, Object>{
          'type' => 'payload',
          'payload' => payloadValue
        }
      }
    };
  }

  /**
   * @description Builds a WhatsApp text parameter map, using a space when the value is blank.
   * @param value Text value for the template parameter.
   * @return Parameter map with type text.
   */
  private static Map<String, Object> buildTextParameter(String value) {
    return new Map<String, Object>{
      'type' => 'text',
      'text' => String.isBlank(value) ? ' ' : value.trim()
    };
  }

  /**
   * @description Safely reads a parameter by index from the resolved params list.
   * @param params Resolved parameter list; may be null.
   * @param index Zero-based index to read.
   * @return Parameter string, or empty string when missing.
   */
  private static String getParam(List<String> params, Integer index) {
    if (params == null || index >= params.size()) {
      return '';
    }
    return params[index];
  }

  /**
   * @description Resolves the quotation document URL from Final Quote Document ID when set,
   *              otherwise from department brochure settings with corporate fallback.
   * @param settings Messaging settings for brochure portal defaults.
   * @param opportunityRecord Opportunity used to resolve the quote or brochure document.
   * @return Public document URL suitable for WhatsApp delivery.
   */
  public static String resolveQuoteDocumentUrl(
    BWM_Messaging_Settings__mdt settings,
    Opportunity opportunityRecord
  ) {
    String finalQuoteDocumentUrl = resolveFinalQuoteDocumentUrl(opportunityRecord);
    if (String.isNotBlank(finalQuoteDocumentUrl)) {
      return finalQuoteDocumentUrl;
    }

    String departmentName = BWM_FieldValueResolver.resolveDepartmentName(
      opportunityRecord
    );
    BWM_BrochureService.BrochureInfo brochure = BWM_BrochureService.getBrochureForDepartment(
      departmentName
    );
    String brochureUrl = BWM_BrochureService.resolveWhatsAppDocumentUrl(
      brochure,
      settings.Default_Brochure_Portal_URL__c
    );

    if (isInaccessibleDocumentUrl(brochureUrl)) {
      brochureUrl = BWM_BrochureService.resolveCorporateWhatsAppUrl(settings);
    }

    if (String.isBlank(brochureUrl)) {
      throw new AuraHandledException(
        'Quotation document URL is not available for WhatsApp delivery.'
      );
    }

    return brochureUrl;
  }

  private static String resolveQuoteDocumentFileName(
    Opportunity opportunityRecord
  ) {
    if (opportunityRecord == null) {
      return null;
    }

    Id contentDocumentId = parsePrimaryContentDocumentId(
      (String) opportunityRecord.get(FINAL_QUOTE_DOCUMENT_ID_FIELD)
    );
    if (contentDocumentId == null) {
      return null;
    }

    ContentVersion versionRecord = queryLatestContentVersion(contentDocumentId);
    if (versionRecord == null || String.isBlank(versionRecord.Title)) {
      return null;
    }

    return formatDocumentFileName(
      versionRecord.Title,
      versionRecord.FileExtension
    );
  }

  private static String formatDocumentFileName(
    String title,
    String fileExtension
  ) {
    String normalizedTitle = title == null ? null : title.trim();
    if (String.isBlank(normalizedTitle)) {
      return null;
    }

    String lowerTitle = normalizedTitle.toLowerCase();
    if (lowerTitle.endsWith('.pdf') || lowerTitle.contains('.')) {
      return normalizedTitle;
    }

    String extension = String.isNotBlank(fileExtension)
      ? fileExtension.trim().toLowerCase()
      : 'pdf';
    if (!extension.startsWith('.')) {
      extension = '.' + extension;
    }

    return normalizedTitle + extension;
  }

  private static String resolveFinalQuoteDocumentUrl(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return null;
    }

    Id contentDocumentId = parsePrimaryContentDocumentId(
      (String) opportunityRecord.get(FINAL_QUOTE_DOCUMENT_ID_FIELD)
    );
    if (contentDocumentId == null) {
      return null;
    }

    ContentVersion versionRecord = queryLatestContentVersion(contentDocumentId);
    if (versionRecord == null) {
      throw new AuraHandledException(
        'Final quote document could not be found for WhatsApp delivery.'
      );
    }

    String documentUrl = resolveExistingPublicUrl(versionRecord);
    if (
      String.isNotBlank(documentUrl) &&
      BWM_BrochureService.isValidWhatsAppDocumentUrl(documentUrl)
    ) {
      return documentUrl;
    }

    throw new AuraHandledException(
      'Final quote document public link is not available. Please try again.'
    );
  }

  private static String resolveExistingPublicUrl(ContentVersion versionRecord) {
    if (versionRecord == null) {
      return null;
    }

    String cachedUrl = BWM_BrochureFileService.resolvePublicDownloadUrl(
      versionRecord.Title,
      versionRecord.Id
    );
    if (String.isNotBlank(cachedUrl)) {
      return cachedUrl;
    }

    List<ContentDistribution> distributions = [
      SELECT ContentDownloadUrl
      FROM ContentDistribution
      WHERE ContentVersionId = :versionRecord.Id
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (
      !distributions.isEmpty() &&
      String.isNotBlank(distributions[0].ContentDownloadUrl)
    ) {
      return distributions[0].ContentDownloadUrl;
    }

    return null;
  }

  private static ContentVersion queryLatestContentVersion(Id contentDocumentId) {
    List<ContentVersion> versions = [
      SELECT Id, Title, FileExtension
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId AND IsLatest = TRUE
      LIMIT 1
    ];
    return versions.isEmpty() ? null : versions[0];
  }

  private static Id parsePrimaryContentDocumentId(String rawValue) {
    if (String.isBlank(rawValue)) {
      return null;
    }

    String primaryValue = rawValue.contains(',')
      ? rawValue.split(',')[0]
      : rawValue;
    primaryValue = primaryValue == null ? null : primaryValue.trim();
    if (String.isBlank(primaryValue)) {
      return null;
    }

    try {
      return (Id) primaryValue;
    } catch (Exception ex) {
      return null;
    }
  }

  /**
   * @description Returns true when the URL is blank or points to inaccessible Salesforce sandbox/file hosts.
   * @param url Candidate document URL.
   * @return True when the URL cannot be used for WhatsApp document delivery.
   */
  private static Boolean isInaccessibleDocumentUrl(String url) {
    if (String.isBlank(url)) {
      return true;
    }
    String normalized = url.toLowerCase();
    return normalized.contains('sandbox.my.salesforce.com') ||
      normalized.contains('file.force.com');
  }
}