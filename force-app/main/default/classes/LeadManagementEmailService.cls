/**
 * @description   Lead campaign Salesforce email template render/send helpers.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class LeadManagementEmailService {
    private static Map<Id, EmailTemplate> templateById = new Map<Id, EmailTemplate>();

    public class RenderedEmail {
        public String subject;
        public String plainTextBody;
        public String htmlBody;
    }

    /**
     * @description Renders a Salesforce email template for a Lead, including product-brief injection when mapped.
     * @param templateId EmailTemplate Id to render.
     * @param leadRecord Lead used for merge fields.
     * @return RenderedEmail with subject/bodies, or null when rendering fails.
     */
    public static RenderedEmail renderTemplate(Id templateId, Lead leadRecord) {
        if (templateId == null || leadRecord == null) {
            return null;
        }

        EmailTemplate templateRecord = templateById.get(templateId);
        if (templateRecord == null) {
            List<EmailTemplate> templates = [
                SELECT Id, Name
                FROM EmailTemplate
                WHERE Id = :templateId
                LIMIT 1
            ];
            if (templates.isEmpty()) {
                return null;
            }
            templateRecord = templates[0];
            templateById.put(templateId, templateRecord);
        }

        BWM_Email_Template_Mapping__mdt mapping = resolveEmailMapping(
            templateRecord.Name,
            templateId
        );
        BWM_EmailTemplateRenderer.RenderedEmail rendered = BWM_EmailTemplateRenderer.render(
            mapping,
            leadRecord
        );
        if (rendered == null || !rendered.fromSalesforceTemplate) {
            return null;
        }

        injectProductBrief(rendered, leadRecord);

        RenderedEmail result = new RenderedEmail();
        result.subject = rendered.subject;
        result.plainTextBody = rendered.plainTextBody;
        result.htmlBody = rendered.htmlBody;
        return hasContent(result) ? result : null;
    }

    /**
     * @description Builds brochure file attachments for the Lead email based on template mapping.
     * @param templateName Email template name used to resolve mapping.
     * @param leadRecord Lead used for brochure department resolution.
     * @return List of EmailFileAttachment values; empty when none apply.
     */
    public static List<Messaging.EmailFileAttachment> buildBrochureAttachments(
        String templateName,
        Lead leadRecord
    ) {
        if (leadRecord == null || String.isBlank(templateName)) {
            return new List<Messaging.EmailFileAttachment>();
        }

        BWM_Email_Template_Mapping__mdt mapping = findEmailMappingByTemplateName(
            templateName
        );
        if (mapping == null) {
            return new List<Messaging.EmailFileAttachment>();
        }

        return BWM_EmailBrochureAttachmentService.buildAttachments(
            BWM_EmailSettingsService.getSettings(),
            mapping,
            leadRecord
        );
    }

    /**
     * @description Resolves email template mapping by template name, falling back to template Id lookup.
     * @param templateName Email template name.
     * @param templateId EmailTemplate Id fallback.
     * @return Matching BWM_Email_Template_Mapping__mdt, or null.
     */
    private static BWM_Email_Template_Mapping__mdt resolveEmailMapping(
        String templateName,
        Id templateId
    ) {
        BWM_Email_Template_Mapping__mdt mapping = findEmailMappingByTemplateName(
            templateName
        );
        if (mapping != null) {
            return mapping;
        }

        mapping = new BWM_Email_Template_Mapping__mdt();
        mapping.Template_Id__c = String.valueOf(templateId);
        mapping.Template_Name__c = templateName;
        return mapping;
    }

    /**
     * @description Finds email template mapping by normalized template name.
     * @param templateName Email template name to match.
     * @return Matching mapping metadata, or null.
     */
    private static BWM_Email_Template_Mapping__mdt findEmailMappingByTemplateName(
        String templateName
    ) {
        if (String.isBlank(templateName)) {
            return null;
        }

        String normalizedTarget = normalizeTemplateName(templateName);
        for (BWM_Email_Template_Mapping__mdt row : [
            SELECT
                Template_Name__c,
                Template_Id__c,
                Brochure_Attachment_Mode__c,
                Subject_Template__c,
                Body_Template__c,
                Sender_Type__c,
                Recipient_Type__c,
                Param1_Field__c,
                Param2_Field__c,
                Param3_Field__c,
                Param4_Field__c,
                Param5_Field__c,
                Param6_Field__c
            FROM BWM_Email_Template_Mapping__mdt
            WHERE Is_Active__c = TRUE
        ]) {
            if (normalizeTemplateName(row.Template_Name__c) == normalizedTarget) {
                return row;
            }
        }
        return null;
    }

    /**
     * @description Normalizes a template name for mapping lookup comparisons.
     * @param templateName Raw template name.
     * @return Normalized template name string.
     */
    private static String normalizeTemplateName(String templateName) {
        return templateName == null
            ? ''
            : templateName.trim().toLowerCase().replace(' ', '_');
    }

    /**
     * @description Injects product-brief content into a rendered Lead email when configured.
     * @param rendered Rendered email content to mutate.
     * @param leadRecord Lead providing product context.
     */
    private static void injectProductBrief(
        BWM_EmailTemplateRenderer.RenderedEmail rendered,
        Lead leadRecord
    ) {
        String plainBrief = BWM_EmailProductBriefService.resolvePlainText(leadRecord);
        if (String.isBlank(plainBrief)) {
            return;
        }

        String htmlBrief = BWM_EmailProductBriefService.resolveHtml(leadRecord);
        if (String.isNotBlank(rendered.htmlBody)) {
            rendered.htmlBody = BWM_EmailProductBriefService.injectIntoContent(
                rendered.htmlBody,
                plainBrief,
                htmlBrief,
                leadRecord
            );
        }
        if (String.isNotBlank(rendered.plainTextBody)) {
            rendered.plainTextBody = BWM_EmailProductBriefService.injectIntoContent(
                rendered.plainTextBody,
                plainBrief,
                htmlBrief,
                leadRecord
            );
        }
    }

    /**
     * @description Returns true when the rendered email has a subject or body content.
     * @param rendered Rendered email DTO to inspect.
     * @return True when subject or body content is present.
     */
    private static Boolean hasContent(RenderedEmail rendered) {
        return rendered != null &&
            (String.isNotBlank(rendered.subject) ||
            String.isNotBlank(rendered.htmlBody) ||
            String.isNotBlank(rendered.plainTextBody));
    }
}