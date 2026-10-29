/**
 * @description   Builds and sends quote WhatsApp/journey message to the Opportunity
 *                customer.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class OpportunityQuoteJourneyService {
    /**
     * @description Validates Opportunity quote prerequisites and sends the quote WhatsApp template to the primary contact.
     * @param opportunityId Opportunity Id that has a synced Quote to send.
     * @return SendWhatsAppResult with sent/skipped counts and messages.
     */
    public static DealerOpportunityWhatsAppService.SendWhatsAppResult sendQuoteToCustomer(
        Id opportunityId
    ) {
        DealerOpportunityWhatsAppService.SendWhatsAppResult result =
            new DealerOpportunityWhatsAppService.SendWhatsAppResult();

        if (opportunityId == null) {
            throw new AuraHandledException('Opportunity Id is required.');
        }

        BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('WhatsApp messaging is disabled or not configured.');
        }

        Opportunity opportunityRecord = BWM_RecordQueryService.queryOpportunity(
            opportunityId
        );

        if (opportunityRecord == null) {
            throw new AuraHandledException('Opportunity not found.');
        }

        if (opportunityRecord.SyncedQuoteId == null) {
            throw new AuraHandledException(
                'Sync Quote is required before sending the quote to the customer.'
            );
        }

        BWM_TemplateResolver.ResolveResult resolveResult = BWM_TemplateResolver.resolve(
            BWM_MessagingConstants.TRIGGER_OPPORTUNITY_SEND_QUOTE_TO_CUSTOMER,
            opportunityRecord
        );

        if (!resolveResult.shouldSend || resolveResult.mapping == null) {
            throw new AuraHandledException(
                String.isNotBlank(resolveResult.skipReason)
                    ? resolveResult.skipReason
                    : 'Send Quote template mapping is not configured.'
            );
        }

        BWM_Template_Mapping__mdt mapping = resolveResult.mapping;
        List<String> templateParams = BWM_FieldValueResolver.resolveParamsForRecord(
            opportunityRecord,
            mapping
        );
        if (templateParams.size() > 2 && String.isBlank(templateParams[2])) {
            throw new AuraHandledException(
                'Quotation Date is required. Populate Quotation Date on the Opportunity or sync a Quote.'
            );
        }

        String phoneNumber = resolvePrimaryContactPhone(opportunityId, settings);
        if (String.isBlank(phoneNumber)) {
            throw new AuraHandledException(
                'No valid mobile number on the primary contact.'
            );
        }

        Boolean publicLinkCreated = OpportunityQuoteWhatsAppPayloadBuilder.prepareFinalQuotePublicLink(
            opportunityRecord
        );
        String documentLink = OpportunityQuoteWhatsAppPayloadBuilder.resolveQuoteDocumentUrl(
            settings,
            opportunityRecord
        );
        String payload = OpportunityQuoteWhatsAppPayloadBuilder.buildPayload(
            settings,
            mapping,
            opportunityRecord,
            phoneNumber,
            documentLink
        );
        String requestCurl = BWM_MessagingCallout.buildRequestCurl(payload);
        String templateName = String.isNotBlank(mapping.WhatsApp_Template_Name__c)
            ? mapping.WhatsApp_Template_Name__c
            : mapping.Journey_Name__c;

        if (publicLinkCreated) {
            System.enqueueJob(
                new SendQuoteWhatsAppQueueable(
                    opportunityRecord.Id,
                    payload,
                    requestCurl,
                    templateName,
                    phoneNumber
                )
            );
            result.sentCount = 1;
            return result;
        }

        String successCode = String.isBlank(settings.WhatsApp_Success_Code__c)
            ? '202'
            : settings.WhatsApp_Success_Code__c;

        try {
            BWM_ApiResponse apiResponse = BWM_ApiResponse.parseWhatsAppDirect(
                BWM_MessagingCallout.send(payload),
                successCode
            );
            BWM_MessageLogService.insertLogs(
                new List<Message_Log__c>{
                    BWM_MessageLogService.buildLogForRecord(
                        opportunityRecord,
                        BWM_MessagingConstants.TRIGGER_OPPORTUNITY_SEND_QUOTE_TO_CUSTOMER,
                        BWM_MessagingConstants.LOG_CHANNEL_WHATSAPP,
                        templateName,
                        phoneNumber,
                        apiResponse.isSuccess
                            ? BWM_MessagingConstants.LOG_STATUS_SENT
                            : BWM_MessagingConstants.LOG_STATUS_FAILED,
                        apiResponse,
                        requestCurl,
                        payload
                    )
                }
            );

            if (apiResponse.isSuccess) {
                result.sentCount = 1;
                OpportunityQuoteEmailService.sendToPrimaryContact(
                    opportunityRecord.Id
                );
            } else {
                result.skippedCount = 1;
                result.messages.add(
                    String.isNotBlank(apiResponse.message)
                        ? apiResponse.message
                        : 'WhatsApp send failed.'
                );
            }
        } catch (Exception ex) {
            result.skippedCount = 1;
            result.messages.add(ex.getMessage());
            BWM_MessageLogService.insertLogs(
                new List<Message_Log__c>{
                    BWM_MessageLogService.buildLogForRecord(
                        opportunityRecord,
                        BWM_MessagingConstants.TRIGGER_OPPORTUNITY_SEND_QUOTE_TO_CUSTOMER,
                        BWM_MessagingConstants.LOG_CHANNEL_WHATSAPP,
                        templateName,
                        phoneNumber,
                        BWM_MessagingConstants.LOG_STATUS_FAILED,
                        buildFailedApiResponse(ex),
                        requestCurl,
                        payload
                    )
                }
            );
        }

        return result;
    }

    /**
     * @description Resolves and formats the primary contact mobile/phone for quote WhatsApp delivery.
     * @param opportunityId Opportunity Id whose primary contact is queried.
     * @param settings Messaging settings used for country-code formatting.
     * @return Formatted phone number, or null when missing or matching the WhatsApp from number.
     */
    private static String resolvePrimaryContactPhone(
        Id opportunityId,
        BWM_Messaging_Settings__mdt settings
    ) {
        List<OpportunityContactRole> contactRoles = [
            SELECT Contact.Phone, Contact.MobilePhone
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId AND IsPrimary = TRUE
            LIMIT 1
        ];

        if (contactRoles.isEmpty() || contactRoles[0].Contact == null) {
            return null;
        }

        // Prefer MobilePhone, but fall back to Phone when MobilePhone is blank
        // or fails formatting (e.g. incomplete MobilePhone with a valid Phone).
        List<String> candidatePhones = new List<String>{
            contactRoles[0].Contact.MobilePhone,
            contactRoles[0].Contact.Phone
        };

        String countryCode = settings == null
            ? null
            : settings.Default_Country_Code__c;

        for (String rawPhone : candidatePhones) {
            if (String.isBlank(rawPhone)) {
                continue;
            }

            String formattedPhone = BWM_PhoneFormatter.formatForMessaging(
                rawPhone,
                countryCode
            );

            if (String.isBlank(formattedPhone)) {
                continue;
            }

            if (
                isSamePhoneNumber(
                    formattedPhone,
                    OpportunityQuoteWhatsAppPayloadBuilder.WHATSAPP_FROM
                )
            ) {
                continue;
            }

            return formattedPhone;
        }

        return null;
    }

    /**
     * @description Compares two phone values by digits only to detect identical numbers.
     * @param phoneA First phone string.
     * @param phoneB Second phone string.
     * @return True when both are non-blank and digit-normalized values match.
     */
    private static Boolean isSamePhoneNumber(String phoneA, String phoneB) {
        if (String.isBlank(phoneA) || String.isBlank(phoneB)) {
            return false;
        }
        return phoneA.replaceAll('[^0-9]', '') == phoneB.replaceAll('[^0-9]', '');
    }

    /**
     * @description Builds a failed BWM_ApiResponse wrapper from an exception for Message_Log__c.
     * @param ex Exception thrown during the WhatsApp callout.
     * @return ApiResponse with message set and httpStatus 0.
     */
    private static BWM_ApiResponse buildFailedApiResponse(Exception ex) {
        BWM_ApiResponse failedResponse = new BWM_ApiResponse();
        failedResponse.message = ex.getMessage();
        failedResponse.httpStatus = 0;
        return failedResponse;
    }

    private class SendQuoteWhatsAppQueueable implements Queueable, Database.AllowsCallouts {
        private final Id opportunityId;
        private final String payload;
        private final String requestCurl;
        private final String templateName;
        private final String phoneNumber;

        private SendQuoteWhatsAppQueueable(
            Id opportunityId,
            String payload,
            String requestCurl,
            String templateName,
            String phoneNumber
        ) {
            this.opportunityId = opportunityId;
            this.payload = payload;
            this.requestCurl = requestCurl;
            this.templateName = templateName;
            this.phoneNumber = phoneNumber;
        }

        public void execute(QueueableContext context) {
            BWM_Messaging_Settings__mdt settings = BWM_SettingsService.getSettings();
            String successCode = settings == null ||
                String.isBlank(settings.WhatsApp_Success_Code__c)
                ? '202'
                : settings.WhatsApp_Success_Code__c;
            Opportunity opportunityRecord = BWM_RecordQueryService.queryOpportunity(
                opportunityId
            );

            try {
                BWM_ApiResponse apiResponse = BWM_ApiResponse.parseWhatsAppDirect(
                    BWM_MessagingCallout.send(payload),
                    successCode
                );
                BWM_MessageLogService.insertLogs(
                    new List<Message_Log__c>{
                        BWM_MessageLogService.buildLogForRecord(
                            opportunityRecord,
                            BWM_MessagingConstants.TRIGGER_OPPORTUNITY_SEND_QUOTE_TO_CUSTOMER,
                            BWM_MessagingConstants.LOG_CHANNEL_WHATSAPP,
                            templateName,
                            phoneNumber,
                            apiResponse.isSuccess
                                ? BWM_MessagingConstants.LOG_STATUS_SENT
                                : BWM_MessagingConstants.LOG_STATUS_FAILED,
                            apiResponse,
                            requestCurl,
                            payload
                        )
                    }
                );
                if (apiResponse.isSuccess) {
                    OpportunityQuoteEmailService.sendToPrimaryContact(
                        opportunityRecord.Id
                    );
                }
            } catch (Exception ex) {
                BWM_MessageLogService.insertLogs(
                    new List<Message_Log__c>{
                        BWM_MessageLogService.buildLogForRecord(
                            opportunityRecord,
                            BWM_MessagingConstants.TRIGGER_OPPORTUNITY_SEND_QUOTE_TO_CUSTOMER,
                            BWM_MessagingConstants.LOG_CHANNEL_WHATSAPP,
                            templateName,
                            phoneNumber,
                            BWM_MessagingConstants.LOG_STATUS_FAILED,
                            buildFailedApiResponse(ex),
                            requestCurl,
                            payload
                        )
                    }
                );
            }
        }
    }
}