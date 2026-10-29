/**
 * @description Sends the final quote email to the primary Opportunity Contact Role
 *              after Send Quote to Customer WhatsApp succeeds.
 * @author Anshita Chanda
 * @date 2026-09-08
 */
public without sharing class OpportunityQuoteEmailService {
    private static final String TEMPLATE_DEVELOPER_NAME = 'Send_Quote_To_Customer';
    private static final String ORG_WIDE_SENDER_EMAIL =
        'noreply@utkarshindialimited.in';

    public static Boolean sendToPrimaryContact(Id opportunityId) {
        try {
            return sendToPrimaryContactInternal(opportunityId);
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.ERROR,
                'OpportunityQuoteEmailService email failed: ' + ex.getMessage()
            );
            return false;
        }
    }

    private static Boolean sendToPrimaryContactInternal(Id opportunityId) {
        if (opportunityId == null) {
            return false;
        }

        List<Opportunity> opportunities = [
            SELECT
                Id,
                CloseDate,
                Quote_Number__c,
                SyncedQuote.QuoteNumber,
                SyncedQuote.submition_date__c,
                Final_Quote_Document_ID__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opportunities.isEmpty()) {
            return false;
        }

        List<OpportunityContactRole> contactRoles = [
            SELECT ContactId, Contact.Name, Contact.Email
            FROM OpportunityContactRole
            WHERE
                OpportunityId = :opportunityId
                AND IsPrimary = TRUE
                AND Contact.Email != NULL
            LIMIT 1
        ];
        if (contactRoles.isEmpty() || contactRoles[0].Contact == null) {
            return false;
        }

        EmailTemplate templateRecord = resolveTemplate();
        Messaging.EmailFileAttachment quoteAttachment = buildFinalQuoteAttachment(
            opportunities[0].Final_Quote_Document_ID__c
        );
        if (templateRecord == null || quoteAttachment == null) {
            return false;
        }

        Opportunity opportunityRecord = opportunities[0];
        Contact contactRecord = contactRoles[0].Contact;
        String quoteNumber = String.isNotBlank(opportunityRecord.Quote_Number__c)
            ? opportunityRecord.Quote_Number__c
            : opportunityRecord.SyncedQuote == null
                ? null
                : opportunityRecord.SyncedQuote.QuoteNumber;
        Date submissionDate =
            opportunityRecord.SyncedQuote == null ||
            opportunityRecord.SyncedQuote.submition_date__c == null
                ? null
                : opportunityRecord.SyncedQuote.submition_date__c.date();

        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        // Do not setTargetObjectId / setWhatId when attaching a PDF.
        // Salesforce can replace binary attachments with a tiny HTML stub otherwise.
        message.setToAddresses(new List<String>{ contactRecord.Email.trim() });
        message.setSaveAsActivity(false);
        message.setUseSignature(false);
        message.setSubject(templateRecord.Subject);
        message.setHtmlBody(
            mergeTemplate(
                templateRecord.HtmlValue,
                contactRecord.Name,
                quoteNumber,
                submissionDate,
                opportunityRecord.CloseDate
            )
        );
        message.setFileAttachments(
            new List<Messaging.EmailFileAttachment>{ quoteAttachment }
        );
        applyOrgWideSender(message);

        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{ message },
                false
            );
            return !results.isEmpty() && results[0].isSuccess();
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.ERROR,
                'OpportunityQuoteEmailService email failed: ' + ex.getMessage()
            );
            return false;
        }
    }

    @TestVisible
    private static Messaging.EmailFileAttachment buildFinalQuoteAttachment(
        String rawContentDocumentIds
    ) {
        Id contentDocumentId = parsePrimaryContentDocumentId(rawContentDocumentIds);
        if (contentDocumentId == null) {
            return null;
        }

        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = TRUE
            LIMIT 1
        ];
        if (versions.isEmpty() || versions[0].VersionData == null) {
            return null;
        }

        ContentVersion versionRecord = versions[0];
        String fileName = versionRecord.Title;
        if (
            String.isNotBlank(versionRecord.FileExtension) &&
            !fileName.toLowerCase().endsWith(
                '.' + versionRecord.FileExtension.toLowerCase()
            )
        ) {
            fileName += '.' + versionRecord.FileExtension;
        }

        Messaging.EmailFileAttachment attachment =
            new Messaging.EmailFileAttachment();
        attachment.setFileName(fileName);
        attachment.setBody(versionRecord.VersionData);
        attachment.setInline(false);
        if (String.isNotBlank(versionRecord.FileExtension)) {
            String extension = versionRecord.FileExtension.toLowerCase();
            if (extension == 'pdf') {
                attachment.setContentType('application/pdf');
            } else if (extension == 'png') {
                attachment.setContentType('image/png');
            } else if (extension == 'jpg' || extension == 'jpeg') {
                attachment.setContentType('image/jpeg');
            } else {
                attachment.setContentType('application/octet-stream');
            }
        }
        return attachment;
    }

    @TestVisible
    private static String mergeTemplate(
        String html,
        String contactName,
        String quoteNumber,
        Date quotationDate,
        Date validTill
    ) {
        if (String.isBlank(html)) {
            return html;
        }
        return html
            .replace('__CONTACT_NAME__', escapeHtml(contactName))
            .replace('__QUOTE_NUMBER__', escapeHtml(quoteNumber))
            .replace('__QUOTATION_DATE__', formatDate(quotationDate))
            .replace('__VALID_TILL__', formatDate(validTill));
    }

    private static String formatDate(Date value) {
        if (value == null) {
            return '';
        }
        return Datetime.newInstance(
                value,
                Time.newInstance(0, 0, 0, 0)
            )
            .format('dd/MM/yyyy');
    }

    private static String escapeHtml(String value) {
        return String.isBlank(value) ? '' : value.escapeHtml4();
    }

    private static Id parsePrimaryContentDocumentId(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }
        String primaryValue = rawValue.contains(',')
            ? rawValue.split(',')[0]
            : rawValue;
        try {
            Id parsedId = (Id) primaryValue.trim();
            return String.valueOf(parsedId).startsWith('069') ? parsedId : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static EmailTemplate resolveTemplate() {
        List<EmailTemplate> templates = [
            SELECT Id, Subject, HtmlValue
            FROM EmailTemplate
            WHERE
                DeveloperName = :TEMPLATE_DEVELOPER_NAME
                AND IsActive = TRUE
            LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0];
    }

    private static void applyOrgWideSender(
        Messaging.SingleEmailMessage message
    ) {
        List<OrgWideEmailAddress> orgWideAddresses = [
            SELECT Id
            FROM OrgWideEmailAddress
            WHERE Address = :ORG_WIDE_SENDER_EMAIL
            LIMIT 1
        ];
        if (!orgWideAddresses.isEmpty()) {
            message.setOrgWideEmailAddressId(orgWideAddresses[0].Id);
        }
    }
}