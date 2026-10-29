public with sharing class BWM_InfobipCampaignEmailService {
    public class SendResult {
        @AuraEnabled
        public Integer sentCount = 0;
        @AuraEnabled
        public Integer skippedCount = 0;
        @AuraEnabled
        public List<String> messages = new List<String>();
    }

    public static SendResult sendToLeads(List<Id> leadIds, String templateId) {
        SendResult result = new SendResult();
        validateRequest(leadIds, templateId);
        BWM_Email_Settings__mdt settings = requireEnabledSettings();

        for (Lead leadRecord : [
            SELECT Id, Name, Email
            FROM Lead
            WHERE Id IN :leadIds
        ]) {
            sendToRecipient(
                settings,
                leadRecord.Name,
                leadRecord.Email,
                templateId,
                result
            );
        }

        return result;
    }

    public static SendResult sendToOpportunities(
        List<Id> opportunityIds,
        String templateId
    ) {
        SendResult result = new SendResult();
        validateRequest(opportunityIds, templateId);
        BWM_Email_Settings__mdt settings = requireEnabledSettings();

        Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>([
            SELECT Id, Name
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);

        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            queryPrimaryContactsByOpportunityId(opportunityIds);

        for (Id opportunityId : opportunityIds) {
            Opportunity opportunityRecord = opportunitiesById.get(opportunityId);
            if (opportunityRecord == null) {
                continue;
            }

            OpportunityContactRole primaryContactRole =
                primaryContactByOpportunityId.get(opportunityId);
            String recipientEmail = primaryContactRole != null &&
                primaryContactRole.Contact != null
                ? primaryContactRole.Contact.Email
                : null;

            sendToRecipient(
                settings,
                opportunityRecord.Name,
                recipientEmail,
                templateId,
                result
            );
        }

        return result;
    }

    private static void validateRequest(List<Id> recordIds, String templateId) {
        if (recordIds == null || recordIds.isEmpty()) {
            throw new AuraHandledException('Select at least one record.');
        }
        if (String.isBlank(templateId)) {
            throw new AuraHandledException('Select an email template.');
        }
    }

    private static BWM_Email_Settings__mdt requireEnabledSettings() {
        BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
        if (settings == null || settings.Is_Enabled__c != true) {
            throw new AuraHandledException('Email is disabled or not configured.');
        }
        if (String.isBlank(settings.Central_Sender_Email__c)) {
            throw new AuraHandledException('Central sender email is not configured.');
        }
        return settings;
    }

    private static void sendToRecipient(
        BWM_Email_Settings__mdt settings,
        String recordName,
        String recipientEmail,
        String templateId,
        SendResult result
    ) {
        if (String.isBlank(recipientEmail)) {
            result.skippedCount++;
            result.messages.add(recordName + ': No email address found.');
            return;
        }

        try {
            HttpResponse response = BWM_EmailCallout.send(
                buildPayload(settings, recipientEmail.trim(), templateId)
            );
            BWM_EmailApiResponse apiResponse = BWM_EmailApiResponse.parse(response);
            if (apiResponse.isSuccess) {
                result.sentCount++;
            } else {
                result.skippedCount++;
                result.messages.add(
                    recordName +
                        ': ' +
                        truncateMessage(apiResponse.message)
                );
            }
        } catch (Exception ex) {
            result.skippedCount++;
            result.messages.add(recordName + ': ' + ex.getMessage());
        }
    }

    private static String buildPayload(
        BWM_Email_Settings__mdt settings,
        String recipientEmail,
        String templateId
    ) {
        Map<String, Object> payload = new Map<String, Object>{
            'messages' => new List<Object>{
                new Map<String, Object>{
                    'sender' => settings.Central_Sender_Email__c.trim(),
                    'destinations' => new List<Object>{
                        new Map<String, Object>{
                            'to' => new List<Object>{
                                new Map<String, Object>{
                                    'destination' => recipientEmail
                                }
                            }
                        }
                    },
                    'content' => new Map<String, Object>{
                        'templateId' => templateId.trim()
                    }
                }
            }
        };
        return JSON.serialize(payload);
    }

    private static Map<Id, OpportunityContactRole> queryPrimaryContactsByOpportunityId(
        List<Id> opportunityIds
    ) {
        Map<Id, OpportunityContactRole> primaryContactByOpportunityId =
            new Map<Id, OpportunityContactRole>();

        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return primaryContactByOpportunityId;
        }

        for (OpportunityContactRole contactRole : [
            SELECT OpportunityId, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId IN :opportunityIds AND IsPrimary = TRUE
        ]) {
            primaryContactByOpportunityId.put(contactRole.OpportunityId, contactRole);
        }

        return primaryContactByOpportunityId;
    }

    private static String truncateMessage(String message) {
        if (String.isBlank(message)) {
            return 'Email send failed.';
        }
        return message.length() > 255 ? message.substring(0, 255) : message;
    }
}