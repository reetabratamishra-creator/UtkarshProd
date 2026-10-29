/**
 * @description   AuraEnabled entry point for Send Quote to Customer button on
 *                Opportunity — delegates to journey send service.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class OpportunityQuoteController {
    /**
     * @description Sends the Opportunity quote to the customer via WhatsApp journey; throws if nothing was sent.
     * @param opportunityId Id of the Opportunity to send the quote for.
     * @return SendWhatsAppResult with send counts and messages when at least one message was sent.
     */
    @AuraEnabled
    public static DealerOpportunityWhatsAppService.SendWhatsAppResult sendQuoteToCustomer(
        Id opportunityId
    ) {
        DealerOpportunityWhatsAppService.SendWhatsAppResult result =
            OpportunityQuoteJourneyService.sendQuoteToCustomer(opportunityId);

        if (result.sentCount == 0) {
            String message = result.messages.isEmpty()
                ? 'WhatsApp message could not be sent.'
                : String.join(result.messages, ' ');
            throw new AuraHandledException(message);
        }

        return result;
    }
}