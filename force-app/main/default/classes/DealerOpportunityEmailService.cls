/**
 * @description   Opportunity campaign Salesforce email template render/send helpers.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
public with sharing class DealerOpportunityEmailService {
    private static Map<Id, EmailTemplate> templateById = new Map<Id, EmailTemplate>();

    private static final Set<String> CORPORATE_BROCHURE_TEMPLATES = new Set<String>{
        'prospect_enq_gen',
        'prospect_not_responding',
        'prospecting_not_responding'
    };

    private static final Set<String> DEPARTMENT_BROCHURE_TEMPLATES = new Set<String>{
        'dealer_enq_dept',
        'u_nurt_not_resp'
    };

    public class RenderedEmail {
        public String subject;
        public String plainTextBody;
        public String htmlBody;
    }

    /**
     * @description Renders a Salesforce email template for an Opportunity, supporting Lightning merge syntax.
     * @param templateId EmailTemplate Id to render.
     * @param opportunityRecord Opportunity used for merge fields.
     * @param whoIdOverride Optional Contact/Lead who Id for rendering.
     * @return RenderedEmail with subject/bodies, or null when rendering fails.
     */
    public static RenderedEmail renderTemplate(
        Id templateId,
        Opportunity opportunityRecord,
        Id whoIdOverride
    ) {
        if (templateId == null || opportunityRecord == null) {
            return null;
        }

        EmailTemplate templateRecord = templateById.get(templateId);
        if (templateRecord == null) {
            List<EmailTemplate> templates = [
                SELECT Id, Subject, HtmlValue, Body, UiType
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
        Id whoId = whoIdOverride != null
            ? whoIdOverride
            : BWM_EmailTemplateRenderer.resolveWhoId(opportunityRecord);
        if (whoId == null) {
            return null;
        }

        if (isLightningTemplate(templateRecord)) {
            return renderLightningTemplate(templateRecord, opportunityRecord, whoId);
        }

        try {
            Messaging.SingleEmailMessage renderedMessage = Messaging.renderStoredEmailTemplate(
                templateId,
                whoId,
                BWM_EmailTemplateRenderer.resolveWhatId(opportunityRecord)
            );

            RenderedEmail rendered = new RenderedEmail();
            rendered.subject = renderedMessage.getSubject();
            rendered.plainTextBody = renderedMessage.getPlainTextBody();
            rendered.htmlBody = renderedMessage.getHtmlBody();
            return hasContent(rendered) ? rendered : null;
        } catch (Exception ex) {
            return null;
        }
    }

    /**
     * @description Returns true when the EmailTemplate is a Lightning (SFX) template.
     * @param templateRecord EmailTemplate to inspect.
     * @return True for Lightning templates.
     */
    private static Boolean isLightningTemplate(EmailTemplate templateRecord) {
        return templateRecord.UiType == 'SFX' ||
            (String.isNotBlank(templateRecord.HtmlValue) &&
            templateRecord.HtmlValue.contains('{{{'));
    }

    /**
     * @description Renders a Lightning email template for an Opportunity with who-Id context.
     * @param templateRecord Lightning EmailTemplate record.
     * @param opportunityRecord Opportunity used for merge fields.
     * @param whoId Who Id used during rendering.
     * @return RenderedEmail DTO, or null when empty.
     */
    private static RenderedEmail renderLightningTemplate(
        EmailTemplate templateRecord,
        Opportunity opportunityRecord,
        Id whoId
    ) {
        Id whatId = opportunityRecord.Id;
        String subject = convertLightningMergeSyntax(templateRecord.Subject);
        String html = convertLightningMergeSyntax(templateRecord.HtmlValue);
        List<String> bodies = new List<String>();
        Boolean hasSubject = String.isNotBlank(subject);
        Boolean hasHtml = String.isNotBlank(html);

        if (hasSubject) {
            bodies.add(subject);
        }
        if (hasHtml) {
            bodies.add(html);
        }
        if (bodies.isEmpty()) {
            return null;
        }

        List<Messaging.RenderEmailTemplateBodyResult> results = Messaging.renderEmailTemplate(
            String.valueOf(whoId),
            String.valueOf(whatId),
            bodies
        );

        RenderedEmail rendered = new RenderedEmail();
        Integer resultIndex = 0;
        if (hasSubject) {
            if (results[resultIndex].getSuccess()) {
                rendered.subject = results[resultIndex].getMergedBody();
            }
            resultIndex++;
        }
        if (hasHtml && results.size() > resultIndex && results[resultIndex].getSuccess()) {
            rendered.htmlBody = results[resultIndex].getMergedBody();
        }

        return hasContent(rendered) ? rendered : null;
    }

    /**
     * @description Converts Lightning merge-field syntax into a renderable format.
     * @param value Template HTML/text containing Lightning merges.
     * @return Converted template string.
     */
    private static String convertLightningMergeSyntax(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.replaceAll('\\{\\{\\{', '{!').replaceAll('\\}\\}\\}', '}');
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

    /**
     * @description Builds brochure file attachments for the Opportunity email based on template mapping.
     * @param templateName Email template name used to resolve mapping.
     * @param opportunityRecord Opportunity used for brochure resolution.
     * @return List of EmailFileAttachment values; empty when none apply.
     */
    public static List<Messaging.EmailFileAttachment> buildBrochureAttachments(
        String templateName,
        Opportunity opportunityRecord
    ) {
        String attachmentMode = resolveBrochureAttachmentMode(templateName);
        if (attachmentMode == null || opportunityRecord == null) {
            return new List<Messaging.EmailFileAttachment>();
        }

        BWM_Email_Template_Mapping__mdt mapping = new BWM_Email_Template_Mapping__mdt(
            Brochure_Attachment_Mode__c = attachmentMode
        );
        return BWM_EmailBrochureAttachmentService.buildAttachments(
            BWM_EmailSettingsService.getSettings(),
            mapping,
            opportunityRecord
        );
    }

    /**
     * @description Resolves brochure attachment mode for the given email template name.
     * @param templateName Email template name.
     * @return Attachment mode string from mapping/config.
     */
    private static String resolveBrochureAttachmentMode(String templateName) {
        if (String.isBlank(templateName)) {
            return null;
        }

        String normalizedName = templateName.trim().toLowerCase();
        if (CORPORATE_BROCHURE_TEMPLATES.contains(normalizedName)) {
            return BWM_EmailConstants.BROCHURE_ATTACH_CORPORATE;
        }
        if (DEPARTMENT_BROCHURE_TEMPLATES.contains(normalizedName)) {
            return BWM_EmailConstants.BROCHURE_ATTACH_DEPARTMENT;
        }
        return null;
    }
}