/**
* @description   Shared Lightning email template render/send helpers for the
*                Utkarsh Escalation Matrix automations.
* @author        Anshita Chanda
* @date          2026-08-10
*/
public without sharing class EscalationMatrixEmailService {
    public enum RecipientGroup {
        OWNER,
            OWNER_AND_CRM,
            HOD_ONLY,
            CRM_HEAD_ONLY,
            HOD_AND_CRM_HEAD,
            ED_SIR
            }
    
    private static Map<String, Id> templateIdByName;
    private static List<Messaging.SingleEmailMessage> queuedMessages;
    private static List<String> queuedCorrelationKeys;
    private static Set<String> successfulSendKeys;
    private static Id cachedOrgWideEmailAddressId;
    private static Boolean orgWideEmailResolved = false;
    private static Map<Id, String> ownerEmailById = new Map<Id, String>();
    private static Map<String, List<String>> roleEmailsByRoleName = new Map<String, List<String>>();
    private static Map<Id, Opportunity> opportunityRenderById = new Map<Id, Opportunity>();
    private static Map<Id, Lead> leadRenderById = new Map<Id, Lead>();
    
    @TestVisible
    private static Map<String, Id> testTemplateIdOverrides;
    
    @TestVisible
    private static Set<String> testRecipientOverrides;
    
    @TestVisible
    private static LeadManagementEmailService.RenderedEmail testLeadRenderedOverride;
    
    @TestVisible
    private static DealerOpportunityEmailService.RenderedEmail testOppRenderedOverride;
    
    @TestVisible
    private static Boolean testSimulateSuccessfulSend = false;
    
    /**
* @description Sends a rendered Lead escalation email to the requested recipient group.
*/
    public static Boolean sendLeadEmail(
        Lead leadRecord,
        String templateName,
        RecipientGroup recipientType
    ) {
        if (leadRecord == null || String.isBlank(templateName)) {
            return false;
        }
        
        LeadManagementEmailService.RenderedEmail rendered = renderLeadTemplate(
            leadRecord,
            templateName
        );
        if (rendered == null) {
            return false;
        }
        
        Set<String> recipients = resolveLeadRecipients(leadRecord, recipientType);
        return sendRenderedEmail(
            leadRecord.Id,
            rendered,
            recipients,
            buildSendKey(leadRecord.Id, templateName)
        );
    }
    
    /**
* @description Sends a rendered Opportunity escalation email to the requested recipient group.
*/
    public static Boolean sendOpportunityEmail(
        Opportunity opportunityRecord,
        String templateName,
        RecipientGroup recipientType
    ) {
        if (opportunityRecord == null || String.isBlank(templateName)) {
            return false;
        }
        
        DealerOpportunityEmailService.RenderedEmail rendered = renderOpportunityTemplate(
            opportunityRecord,
            templateName
        );
        if (rendered == null) {
            return false;
        }
        
        Set<String> recipients = resolveOpportunityRecipients(
            opportunityRecord,
            recipientType
        );
        return sendRenderedEmail(
            resolveOpportunityTargetObjectId(opportunityRecord),
            rendered,
            recipients,
            buildSendKey(opportunityRecord.Id, templateName)
        );
    }
    
    /**
* @description Sends a task overdue email to the Lead or Opportunity owner.
*/
    public static Boolean sendTaskOverdueOwnerEmail(
        Task taskRecord,
        String templateName,
        Id targetObjectId,
        String ownerEmail
    ) {
        if (taskRecord == null || String.isBlank(templateName) || String.isBlank(ownerEmail)) {
            return false;
        }
        
        Id templateId = resolveTemplateId(templateName);
        if (templateId == null || targetObjectId == null) {
            return false;
        }
        
        SObject targetRecord = targetObjectId.getSobjectType() == Lead.SObjectType
            ? (SObject) queryLeadForRender(targetObjectId)
            : (SObject) queryOpportunityForRender(targetObjectId);
        
        if (targetRecord == null) {
            return false;
        }
        
        LeadManagementEmailService.RenderedEmail leadRendered;
        DealerOpportunityEmailService.RenderedEmail oppRendered;
        
        if (targetRecord instanceof Lead) {
            leadRendered = renderLeadTemplate((Lead) targetRecord, templateName);
            if (leadRendered == null) {
                return false;
            }
            return sendRenderedEmail(
                targetObjectId,
                leadRendered,
                new Set<String>{ ownerEmail.trim().toLowerCase() },
                buildSendKey(targetObjectId, templateName)
            );
        }
        
        oppRendered = renderOpportunityTemplate((Opportunity) targetRecord, templateName);
        if (oppRendered == null) {
            return false;
        }
        return sendRenderedEmail(
            targetObjectId,
            oppRendered,
            new Set<String>{ ownerEmail.trim().toLowerCase() },
            buildSendKey(targetObjectId, templateName)
        );
    }
    
    /**
* @description Renders a Task-related Lightning template against the Task Id
*              so {{{Task.Subject}}} / {{{Task.Owner.Name}}} merge. Recipients
*              still come from the related Lead or Opportunity.
*/
    public static Boolean sendTaskRelatedEmail(
        Task taskRecord,
        String templateName,
        RecipientGroup recipientType,
        Lead leadRecord,
        Opportunity opportunityRecord
    ) {
        if (taskRecord == null || taskRecord.Id == null || String.isBlank(templateName)) {
            return false;
        }
        
        if (Test.isRunningTest() && testLeadRenderedOverride != null && leadRecord != null) {
            return sendLeadEmail(leadRecord, templateName, recipientType);
        }
        if (Test.isRunningTest() && testOppRenderedOverride != null && opportunityRecord != null) {
            return sendOpportunityEmail(opportunityRecord, templateName, recipientType);
        }
        
        Id templateId = resolveTemplateId(templateName);
        if (templateId == null) {
            return false;
        }
        
        Set<String> recipients = leadRecord != null
            ? resolveLeadRecipients(leadRecord, recipientType)
            : resolveOpportunityRecipients(opportunityRecord, recipientType);
        if (recipients == null || recipients.isEmpty()) {
            return false;
        }
        
        DealerOpportunityEmailService.RenderedEmail rendered = renderTaskTemplate(
            templateId,
            taskRecord
        );
        if (rendered == null) {
            return false;
        }
        
        Id correlationRecordId = leadRecord != null
            ? leadRecord.Id
            : (opportunityRecord != null ? opportunityRecord.Id : taskRecord.Id);
                Id targetObjectId = leadRecord != null
                ? leadRecord.Id
                : (opportunityRecord != null
                   ? resolveOpportunityTargetObjectId(opportunityRecord)
                   : taskRecord.OwnerId);
                       
                       return sendRenderedEmail(
                           targetObjectId,
                           rendered,
                           recipients,
                           buildSendKey(correlationRecordId, templateName)
                       );
    }
    
    /**
* @description True when the last flush successfully sent the email for this record/template.
*/
    public static Boolean wasSendSuccessful(Id recordId, String templateName) {
        if (recordId == null || String.isBlank(templateName)) {
            return false;
        }
        if (Test.isRunningTest() && testSimulateSuccessfulSend) {
            return true;
        }
        return successfulSendKeys != null &&
            successfulSendKeys.contains(buildSendKey(recordId, templateName));
    }
    
    /**
* @description Partial Opportunity updates; skips approval-locked records.
*/
    public static void updateOpportunitiesAllowPartial(List<Opportunity> opportunitiesToUpdate) {
        if (opportunitiesToUpdate == null || opportunitiesToUpdate.isEmpty()) {
            return;
        }
        
        List<Opportunity> safeUpdates = new List<Opportunity>();
        for (Opportunity opportunityRecord : opportunitiesToUpdate) {
            if (opportunityRecord == null || opportunityRecord.Id == null) {
                continue;
            }
            if (Approval.isLocked(opportunityRecord.Id)) {
                System.debug(
                    LoggingLevel.WARN,
                    'Skipped escalation flag update for locked Opportunity ' + opportunityRecord.Id
                );
                continue;
            }
            safeUpdates.add(opportunityRecord);
        }
        
        if (!safeUpdates.isEmpty()) {
            Database.update(safeUpdates, false);
        }
    }
    
    public static String getRoleDepartmentName(String department) {
        Map<String, String> departmentMap = new Map<String, String>{
            'Transmission & Telecom Tower' => 'Transmission Tower'
                };
                    return departmentMap.containsKey(department) ? departmentMap.get(department) : department;
    }
    
    public static Set<String> resolveLeadRecipients(
        Lead leadRecord,
        RecipientGroup recipientType
    ) {
        if (
            Test.isRunningTest() &&
            testRecipientOverrides != null &&
            !testRecipientOverrides.isEmpty()
        ) {
            return new Set<String>(testRecipientOverrides);
        }
        
        Set<String> recipients = new Set<String>();
        String department = getRoleDepartmentName(leadRecord.Department_NameFormula__c);
        
        if (
            recipientType == RecipientGroup.OWNER ||
            recipientType == RecipientGroup.OWNER_AND_CRM
        ) {
            addOwnerEmail(leadRecord.OwnerId, recipients);
        }
        
        if (recipientType == RecipientGroup.OWNER_AND_CRM) {
            addCrmHeadEmails(leadRecord.CRM_User_Email_Formula__c, department, recipients);
        }
        
        if (recipientType == RecipientGroup.HOD_ONLY) {
            addRoleEmails(department + ' HOD', recipients);
        }
        
        if (recipientType == RecipientGroup.CRM_HEAD_ONLY) {
            addRoleEmails('Utkarsh CRM Head', recipients);
        }
        
        if (recipientType == RecipientGroup.HOD_AND_CRM_HEAD) {
            addRoleEmails(department + ' HOD', recipients);
            addRoleEmails('Utkarsh CRM Head', recipients);
            addCrmHeadEmails(leadRecord.CRM_User_Email_Formula__c, department, recipients);
        }
        
        if (recipientType == RecipientGroup.ED_SIR) {
            addRoleEmails('Utkarsh ED', recipients);
        }
        
        return recipients;
    }
    
    public static Set<String> resolveOpportunityRecipients(
        Opportunity opportunityRecord,
        RecipientGroup recipientType
    ) {
        if (
            Test.isRunningTest() &&
            testRecipientOverrides != null &&
            !testRecipientOverrides.isEmpty()
        ) {
            return new Set<String>(testRecipientOverrides);
        }
        
        Set<String> recipients = new Set<String>();
        String department = getRoleDepartmentName(
            String.isNotBlank(opportunityRecord.Department_NameFormula__c)
            ? opportunityRecord.Department_NameFormula__c
            : opportunityRecord.Department_Name__c
        );
        
        if (
            recipientType == RecipientGroup.OWNER ||
            recipientType == RecipientGroup.OWNER_AND_CRM
        ) {
            addOwnerEmail(opportunityRecord.OwnerId, recipients);
        }
        
        if (recipientType == RecipientGroup.OWNER_AND_CRM) {
            addCrmHeadEmails(
                opportunityRecord.CRM_User_Email_Formula__c,
                department,
                recipients
            );
        }
        
        if (recipientType == RecipientGroup.HOD_ONLY) {
            addRoleEmails(department + ' HOD', recipients);
        }
        
        if (recipientType == RecipientGroup.CRM_HEAD_ONLY) {
            addRoleEmails('Utkarsh CRM Head', recipients);
        }
        
        if (recipientType == RecipientGroup.HOD_AND_CRM_HEAD) {
            addRoleEmails(department + ' HOD', recipients);
            addRoleEmails('Utkarsh CRM Head', recipients);
            addCrmHeadEmails(
                opportunityRecord.CRM_User_Email_Formula__c,
                department,
                recipients
            );
        }
        
        if (recipientType == RecipientGroup.ED_SIR) {
            addRoleEmails('Utkarsh ED', recipients);
        }
        
        return recipients;
    }
    
    public static Boolean hasNoActivitySince(Datetime anchorDate, Date lastActivityDate) {
        if (anchorDate == null) {
            return false;
        }
        if (lastActivityDate == null) {
            return true;
        }
        return lastActivityDate <= anchorDate.date();
    }
    
    public static Long hoursSince(Datetime anchorDate) {
        if (anchorDate == null) {
            return 0;
        }
        return (System.now().getTime() - anchorDate.getTime()) / (1000 * 60 * 60);
    }
    
    public static Long daysSince(Datetime anchorDate) {
        if (anchorDate == null) {
            return 0;
        }
        return anchorDate.date().daysBetween(Date.today());
    }
    
    public static Long daysSince(Date anchorDate) {
        if (anchorDate == null) {
            return 0;
        }
        return anchorDate.daysBetween(Date.today());
    }
    
    @TestVisible
    static void setTestTemplateId(String templateName, Id templateId) {
        if (testTemplateIdOverrides == null) {
            testTemplateIdOverrides = new Map<String, Id>();
        }
        testTemplateIdOverrides.put(templateName, templateId);
    }
    
    @TestVisible
    static void clearTestTemplateIds() {
        clearTestState();
    }
    
    @TestVisible
    static void clearTestState() {
        testTemplateIdOverrides = null;
        templateIdByName = null;
        testRecipientOverrides = null;
        testLeadRenderedOverride = null;
        testOppRenderedOverride = null;
        testSimulateSuccessfulSend = false;
        queuedMessages = null;
        queuedCorrelationKeys = null;
        successfulSendKeys = null;
        cachedOrgWideEmailAddressId = null;
        orgWideEmailResolved = false;
        ownerEmailById.clear();
        roleEmailsByRoleName.clear();
        opportunityRenderById.clear();
        leadRenderById.clear();
    }
    
    /**
* @description Flushes queued emails (one sendEmail invocation per up to 10 messages).
*/
    public static void flushQueuedEmails() {
        if (queuedMessages == null || queuedMessages.isEmpty()) {
            return;
        }
        
        if (successfulSendKeys == null) {
            successfulSendKeys = new Set<String>();
        }
        
        if (Test.isRunningTest() && testSimulateSuccessfulSend) {
            if (queuedCorrelationKeys != null) {
                successfulSendKeys.addAll(queuedCorrelationKeys);
            }
            queuedMessages.clear();
            queuedCorrelationKeys = null;
            return;
        }
        
        List<Messaging.SingleEmailMessage> toSend = new List<Messaging.SingleEmailMessage>(
            queuedMessages
        );
        List<String> keysToSend = queuedCorrelationKeys == null
            ? new List<String>()
            : new List<String>(queuedCorrelationKeys);
        queuedMessages.clear();
        queuedCorrelationKeys = null;
        
        Integer index = 0;
        while (index < toSend.size()) {
            List<Messaging.SingleEmailMessage> chunk = new List<Messaging.SingleEmailMessage>();
            List<String> keyChunk = new List<String>();
            while (index < toSend.size() && chunk.size() < 10) {
                chunk.add(toSend[index]);
                if (index < keysToSend.size()) {
                    keyChunk.add(keysToSend[index]);
                }
                index++;
            }
            try {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(chunk, false);
                for (Integer resultIndex = 0; resultIndex < results.size(); resultIndex++) {
                    if (results[resultIndex].isSuccess() && resultIndex < keyChunk.size()) {
                        successfulSendKeys.add(keyChunk[resultIndex]);
                    }
                }
            } catch (Exception ex) {
                // Org daily Single Email quota exhausted — stop flush without failing the batch.
                if (isEmailLimitExceeded(ex)) {
                    return;
                }
                throw ex;
            }
        }
    }
    
    private static Boolean isEmailLimitExceeded(Exception ex) {
        if (ex == null || String.isBlank(ex.getMessage())) {
            return false;
        }
        String message = ex.getMessage().toUpperCase();
        return message.contains('SINGLE_EMAIL_LIMIT_EXCEEDED') ||
            message.contains('EMAIL LIMIT EXCEEDED');
    }
    
    private static String buildSendKey(Id recordId, String templateName) {
        return String.valueOf(recordId) + '|' + templateName;
    }
    
    private static LeadManagementEmailService.RenderedEmail renderLeadTemplate(
        Lead leadRecord,
        String templateName
    ) {
        if (Test.isRunningTest() && testLeadRenderedOverride != null) {
            return testLeadRenderedOverride;
        }
        
        Id templateId = resolveTemplateId(templateName);
        if (templateId == null) {
            return null;
        }
        return LeadManagementEmailService.renderTemplate(templateId, leadRecord);
    }
    
    private static DealerOpportunityEmailService.RenderedEmail renderTaskTemplate(
        Id templateId,
        Task taskRecord
    ) {
        if (templateId == null || taskRecord == null || taskRecord.Id == null) {
            return null;
        }
        
        Id whoId = taskRecord.WhoId != null ? taskRecord.WhoId : taskRecord.OwnerId;
        try {
            Messaging.SingleEmailMessage renderedMessage = Messaging.renderStoredEmailTemplate(
                templateId,
                whoId,
                taskRecord.Id
            );
            DealerOpportunityEmailService.RenderedEmail rendered = new DealerOpportunityEmailService.RenderedEmail();
            rendered.subject = renderedMessage.getSubject();
            rendered.htmlBody = renderedMessage.getHtmlBody();
            rendered.plainTextBody = renderedMessage.getPlainTextBody();
            if (
                String.isBlank(rendered.subject) &&
                String.isBlank(rendered.htmlBody) &&
                String.isBlank(rendered.plainTextBody)
            ) {
                return null;
            }
            return rendered;
        } catch (Exception ex) {
            System.debug(
                LoggingLevel.ERROR,
                'Task template render failed for ' +
                taskRecord.Id +
                ': ' +
                ex.getMessage()
            );
            return null;
        }
    }
    
    private static DealerOpportunityEmailService.RenderedEmail renderOpportunityTemplate(
        Opportunity opportunityRecord,
        String templateName
    ) {
        if (Test.isRunningTest() && testOppRenderedOverride != null) {
            return testOppRenderedOverride;
        }
        
        Id templateId = resolveTemplateId(templateName);
        if (templateId == null) {
            return null;
        }
        
        Opportunity renderRecord = queryOpportunityForRender(opportunityRecord.Id);
        if (renderRecord == null) {
            return null;
        }
        
        return DealerOpportunityEmailService.renderTemplate(
            templateId,
            renderRecord,
            null
        );
    }
    
    private static Boolean sendRenderedEmail(
        Id targetObjectId,
        LeadManagementEmailService.RenderedEmail rendered,
        Set<String> recipients,
        String correlationKey
    ) {
        if (rendered == null || recipients == null || recipients.isEmpty()) {
            return false;
        }
        
        if (Test.isRunningTest() && testSimulateSuccessfulSend) {
            if (successfulSendKeys == null) {
                successfulSendKeys = new Set<String>();
            }
            if (String.isNotBlank(correlationKey)) {
                successfulSendKeys.add(correlationKey);
            }
            return true;
        }
        
        enqueueMessage(
            buildMessage(
                targetObjectId,
                rendered.subject,
                rendered.htmlBody,
                rendered.plainTextBody,
                new List<String>(recipients)
            ),
            correlationKey
        );
        // Tests expect immediate send; production batches call flushQueuedEmails().
        if (Test.isRunningTest()) {
            flushQueuedEmails();
        }
        return true;
    }
    
    private static Boolean sendRenderedEmail(
        Id targetObjectId,
        DealerOpportunityEmailService.RenderedEmail rendered,
        Set<String> recipients,
        String correlationKey
    ) {
        if (rendered == null || recipients == null || recipients.isEmpty()) {
            return false;
        }
        
        if (Test.isRunningTest() && testSimulateSuccessfulSend) {
            if (successfulSendKeys == null) {
                successfulSendKeys = new Set<String>();
            }
            if (String.isNotBlank(correlationKey)) {
                successfulSendKeys.add(correlationKey);
            }
            return true;
        }
        
        enqueueMessage(
            buildMessage(
                targetObjectId,
                rendered.subject,
                rendered.htmlBody,
                rendered.plainTextBody,
                new List<String>(recipients)
            ),
            correlationKey
        );
        if (Test.isRunningTest()) {
            flushQueuedEmails();
        }
        return true;
    }
    
    private static void enqueueMessage(
        Messaging.SingleEmailMessage message,
        String correlationKey
    ) {
        if (queuedMessages == null) {
            queuedMessages = new List<Messaging.SingleEmailMessage>();
            queuedCorrelationKeys = new List<String>();
        }
        queuedMessages.add(message);
        queuedCorrelationKeys.add(correlationKey);
    }
    
    private static Messaging.SingleEmailMessage buildMessage(
        Id targetObjectId,
        String subject,
        String htmlBody,
        String plainTextBody,
        List<String> toAddresses
    ) {
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setToAddresses(toAddresses);
        message.setSubject(subject);
        message.setSaveAsActivity(false);
        message.setTargetObjectId(targetObjectId);
        message.setTreatTargetObjectAsRecipient(false);
        
        if (String.isNotBlank(htmlBody)) {
            message.setHtmlBody(htmlBody);
        }
        if (String.isNotBlank(plainTextBody)) {
            message.setPlainTextBody(plainTextBody);
        }
        
        applyOrgWideSender(message);
        return message;
    }
    
    private static Id resolveTemplateId(String templateName) {
        if (Test.isRunningTest() && testTemplateIdOverrides != null) {
            return testTemplateIdOverrides.get(templateName);
        }
        
        if (templateIdByName == null) {
            templateIdByName = new Map<String, Id>();
            for (EmailTemplate templateRecord : [
                SELECT Id, Name
                FROM EmailTemplate
                WHERE Folder.Name = 'Utkarsh Escalation Matrix Template'
            ]) {
                templateIdByName.put(templateRecord.Name, templateRecord.Id);
            }
        }
        
        return templateIdByName.get(templateName);
    }
    
    private static void addOwnerEmail(Id ownerId, Set<String> recipients) {
        if (ownerId == null) {
            return;
        }
        
        if (!ownerEmailById.containsKey(ownerId)) {
            List<User> owners = [
                SELECT Email
                FROM User
                WHERE Id = :ownerId AND Email != NULL
                LIMIT 1
            ];
            ownerEmailById.put(
                ownerId,
                owners.isEmpty() ? null : owners[0].Email.trim().toLowerCase()
            );
        }
        
        String ownerEmail = ownerEmailById.get(ownerId);
        if (String.isNotBlank(ownerEmail)) {
            recipients.add(ownerEmail);
        }
    }
    
    private static void addCrmHeadEmails(
        String crmFormulaEmail,
        String department,
        Set<String> recipients
    ) {
        if (String.isNotBlank(crmFormulaEmail)) {
            recipients.add(crmFormulaEmail.trim().toLowerCase());
        }
        addRoleEmails(department + ' CRM User', recipients);
    }
    
    private static void addRoleEmails(String roleName, Set<String> recipients) {
        if (String.isBlank(roleName)) {
            return;
        }
        
        if (!roleEmailsByRoleName.containsKey(roleName)) {
            List<String> roleEmails = new List<String>();
            for (User userRecord : [
                SELECT Email
                FROM User
                WHERE IsActive = TRUE AND UserRole.Name = :roleName AND Email != NULL
            ]) {
                roleEmails.add(userRecord.Email.trim().toLowerCase());
            }
            roleEmailsByRoleName.put(roleName, roleEmails);
        }
        
        recipients.addAll(roleEmailsByRoleName.get(roleName));
    }
    
    private static void applyOrgWideSender(Messaging.SingleEmailMessage message) {
        BWM_Email_Settings__mdt settings = BWM_EmailSettingsService.getSettings();
        if (settings == null || String.isBlank(settings.Central_Sender_Email__c)) {
            return;
        }
        
        if (!orgWideEmailResolved) {
            List<OrgWideEmailAddress> orgWideAddresses = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE Address = :settings.Central_Sender_Email__c.trim()
                LIMIT 1
            ];
            cachedOrgWideEmailAddressId = orgWideAddresses.isEmpty()
                ? null
                : orgWideAddresses[0].Id;
            orgWideEmailResolved = true;
        }
        
        if (cachedOrgWideEmailAddressId != null) {
            message.setOrgWideEmailAddressId(cachedOrgWideEmailAddressId);
        }
    }
    
    private static Id resolveOpportunityTargetObjectId(Opportunity opportunityRecord) {
        Opportunity renderRecord = queryOpportunityForRender(opportunityRecord.Id);
        if (renderRecord == null) {
            return opportunityRecord.OwnerId;
        }
        
        if (renderRecord.ContactId != null) {
            return renderRecord.ContactId;
        }
        
        return renderRecord.OwnerId;
    }
    
    private static Lead queryLeadForRender(Id leadId) {
        if (leadRenderById.containsKey(leadId)) {
            return leadRenderById.get(leadId);
        }
        
        List<Lead> rows = [
            SELECT
            Id,
            Name,
            OwnerId,
            Owner.Name,
            Owner.Email,
            Department_Name__c,
            Department_NameFormula__c,
            CRM_User_Email_Formula__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        Lead renderRecord = rows.isEmpty() ? null : rows[0];
        leadRenderById.put(leadId, renderRecord);
        return renderRecord;
    }
    
    private static Opportunity queryOpportunityForRender(Id opportunityId) {
        if (opportunityRenderById.containsKey(opportunityId)) {
            return opportunityRenderById.get(opportunityId);
        }
        
        List<Opportunity> rows = [
            SELECT
            Id,
            Name,
            OwnerId,
            Owner.Name,
            Owner.Email,
            ContactId,
            Department_Name__c,
            Department_NameFormula__c,
            CRM_User_Email_Formula__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        Opportunity renderRecord = rows.isEmpty() ? null : rows[0];
        opportunityRenderById.put(opportunityId, renderRecord);
        return renderRecord;
    }
    
    
    // =============================================================================
    // (anywhere inside the class body, e.g. right after wasSendSuccessful()).
    // Nothing existing is modified or removed. They reuse your existing private
    // helpers: renderLeadTemplate, resolveLeadRecipients, sendRenderedEmail.
    // =============================================================================
    
    /**
* @description NEW: Sends ONE consolidated email for a group of Leads that share
*              the same recipients (e.g. all leads of one owner).
*              - Subject / intro come from the existing Lightning template
*                (rendered against the first lead of the group).
*              - A table listing ALL leads of the group is appended to the body.
*              - The email is queued; the caller must call flushQueuedEmails().
* @param leadRecords    Leads to list in the email (all share the same recipients)
* @param templateName   Existing Lightning email template name
* @param recipientType  Existing recipient group (OWNER / HOD_AND_CRM_HEAD / ED_SIR)
* @param groupKey       Unique key of the group (used to track send success)
* @param hoursByLeadId  Hours since last activity per lead (shown in the table)
*/
    public static Boolean sendConsolidatedLeadEmail(
        List<Lead> leadRecords,
        String templateName,
        RecipientGroup recipientType,
        String groupKey,
        Map<Id, Long> hoursByLeadId
    ) {
        if (
            leadRecords == null ||
            leadRecords.isEmpty() ||
            String.isBlank(templateName) ||
            String.isBlank(groupKey)
        ) {
            return false;
        }
        
        Lead firstLead = leadRecords[0];
        
        // Reuse the existing template (render against the first lead of the group).
        LeadManagementEmailService.RenderedEmail baseRendered = renderLeadTemplate(
            firstLead,
            templateName
        );
        if (baseRendered == null) {
            return false;
        }
        
        // Reuse the existing recipient logic. All leads in this group share recipients.
        Set<String> recipients = resolveLeadRecipients(firstLead, recipientType);
        if (recipients == null || recipients.isEmpty()) {
            return false;
        }
        
        // Build a NEW rendered object so the shared/test-override instance is not mutated.
        // (Assumes LeadManagementEmailService.RenderedEmail has a no-arg constructor and
        //  subject/htmlBody/plainTextBody fields, as DealerOpportunityEmailService's does.)
        LeadManagementEmailService.RenderedEmail consolidated = new LeadManagementEmailService.RenderedEmail();
        
        String baseSubject = String.isBlank(baseRendered.subject)
            ? templateName
            : baseRendered.subject;
        consolidated.subject = baseSubject + ' (' + leadRecords.size() + ' Leads)';
        
        // CHANGE: "Regards" closing is split off the template body and placed AFTER the table.
        String rawHtml = String.isNotBlank(baseRendered.htmlBody)
            ? baseRendered.htmlBody
            : (String.isNotBlank(baseRendered.plainTextBody)
               ? baseRendered.plainTextBody.replace('\n', '<br/>')
               : '');
                   List<String> htmlParts = splitClosingHtml(rawHtml);
        
        consolidated.htmlBody =
            htmlParts[0] +
            '<br/><p><b>Leads requiring attention (' + leadRecords.size() + '):</b></p>' +
            buildConsolidatedLeadHtml(leadRecords, hoursByLeadId) +
            '<br/>' + htmlParts[1];
        
        List<String> textParts = splitClosingText(baseRendered.plainTextBody);
        consolidated.plainTextBody =
            textParts[0] +
            '\n\nLeads requiring attention (' + leadRecords.size() + '):\n' +
            buildConsolidatedLeadText(leadRecords, hoursByLeadId) +
            '\n\n' + textParts[1];
        
        return sendRenderedEmail(
            firstLead.Id, // targetObjectId only (treatTargetObjectAsRecipient = false)
            consolidated,
            recipients,
            buildConsolidatedSendKey(groupKey, templateName)
        );
    }
    
    /**
* @description NEW: True when the consolidated email of this group/template was sent
*              successfully by the last flushQueuedEmails().
*/
    public static Boolean wasConsolidatedSendSuccessful(String groupKey, String templateName) {
        if (String.isBlank(groupKey) || String.isBlank(templateName)) {
            return false;
        }
        if (Test.isRunningTest() && testSimulateSuccessfulSend) {
            return true;
        }
        return successfulSendKeys != null &&
            successfulSendKeys.contains(buildConsolidatedSendKey(groupKey, templateName));
    }
    
    // NEW: send-key for consolidated emails (one key per group, not per record).
    private static String buildConsolidatedSendKey(String groupKey, String templateName) {
        return 'GROUP|' + groupKey + '|' + templateName;
    }
    
    // NEW (Regards change): splits a rendered HTML body into [intro, closing] at the last "Regards".
    // Cut is moved back to the start of the enclosing <p>/<div> so no tag is broken.
    private static List<String> splitClosingHtml(String html) {
        if (String.isBlank(html)) {
            return new List<String>{ '', '' };
                }
        String lower = html.toLowerCase();
        Integer idx = lower.lastIndexOf('regards');
        if (idx < 0) {
            return new List<String>{ html, '' };
                }
        Integer blockStart = Math.max(lower.lastIndexOf('<p', idx), lower.lastIndexOf('<div', idx));
        Integer lastClose = Math.max(lower.lastIndexOf('</p>', idx), lower.lastIndexOf('</div>', idx));
        Integer cut = (blockStart >= 0 && blockStart > lastClose) ? blockStart : idx;
        return new List<String>{ html.substring(0, cut), html.substring(cut) };
            }
    
    // NEW (Regards change): plain-text version of the same split.
    private static List<String> splitClosingText(String text) {
        if (String.isBlank(text)) {
            return new List<String>{ '', '' };
                }
        Integer idx = text.toLowerCase().lastIndexOf('regards');
        if (idx < 0) {
            return new List<String>{ text, '' };
                }
        return new List<String>{ text.substring(0, idx), text.substring(idx) };
            }
    
    // NEW: HTML table listing every lead of the group.
    private static String buildConsolidatedLeadHtml(
        List<Lead> leadRecords,
        Map<Id, Long> hoursByLeadId
    ) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String html =
            '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;font-size:13px;">' +
            '<tr style="background:#f3f3f3;">' +
            '<th>#</th><th>Lead</th><th>Owner</th><th>Department</th><th>Hours Since Last Activity</th>' +
            '</tr>';
        
        Integer rowNumber = 1;
        for (Lead leadRecord : leadRecords) {
            Long hours = (hoursByLeadId != null && hoursByLeadId.containsKey(leadRecord.Id))
                ? hoursByLeadId.get(leadRecord.Id)
                : 0;
            String leadName = String.isBlank(leadRecord.Name) ? String.valueOf(leadRecord.Id) : leadRecord.Name;
            String ownerName = leadRecord.Owner != null && leadRecord.Owner.Name != null
                ? leadRecord.Owner.Name
                : '';
            String department = leadRecord.Department_NameFormula__c != null
                ? leadRecord.Department_NameFormula__c
                : '';
            
            html +=
                '<tr>' +
                '<td>' + rowNumber + '</td>' +
                '<td><a href="' + baseUrl + '/' + leadRecord.Id + '">' + leadName.escapeHtml4() + '</a></td>' +
                '<td>' + ownerName.escapeHtml4() + '</td>' +
                '<td>' + department.escapeHtml4() + '</td>' +
                '<td>' + hours + '</td>' +
                '</tr>';
            rowNumber++;
        }
        return html + '</table>';
    }
    
    // NEW: plain-text version of the same list (for email clients without HTML).
    private static String buildConsolidatedLeadText(
        List<Lead> leadRecords,
        Map<Id, Long> hoursByLeadId
    ) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<String> lines = new List<String>();
        Integer rowNumber = 1;
        for (Lead leadRecord : leadRecords) {
            Long hours = (hoursByLeadId != null && hoursByLeadId.containsKey(leadRecord.Id))
                ? hoursByLeadId.get(leadRecord.Id)
                : 0;
            lines.add(
                rowNumber + '. ' + leadRecord.Name + ' | ' +
                (leadRecord.Owner != null ? leadRecord.Owner.Name : '') + ' | ' +
                leadRecord.Department_NameFormula__c + ' | ' +
                hours + ' hrs | ' + baseUrl + '/' + leadRecord.Id
            );
            rowNumber++;
        }
        return String.join(lines, '\n');
    }
    
    // =============================================================================
    // resolveOpportunityRecipients, resolveOpportunityTargetObjectId,
    // sendRenderedEmail, buildConsolidatedSendKey and wasConsolidatedSendSuccessful
    // (those two already exist from the Lead change).
    // =============================================================================
    
    /**
* @description NEW: Sends ONE consolidated email for a group of Opportunities that
*              share the same recipients.
*              - Subject / intro come from the existing Lightning template
*                (rendered against the first opportunity of the group).
*              - A table listing ALL opportunities of the group is appended.
*              - The email is queued; the caller must call flushQueuedEmails().
* @param opportunityRecords   Opportunities to list (all share the same recipients)
* @param templateName         Existing Lightning email template name
* @param recipientType        Existing recipient group
* @param groupKey             Unique key of the group (used to track send success)
* @param daysByOpportunityId  Days since last activity per opportunity (shown in table)
*/
    public static Boolean sendConsolidatedOpportunityEmail(
        List<Opportunity> opportunityRecords,
        String templateName,
        RecipientGroup recipientType,
        String groupKey,
        Map<Id, Long> daysByOpportunityId
    ) {
        if (
            opportunityRecords == null ||
            opportunityRecords.isEmpty() ||
            String.isBlank(templateName) ||
            String.isBlank(groupKey)
        ) {
            return false;
        }
        
        Opportunity firstOpportunity = opportunityRecords[0];
        
        DealerOpportunityEmailService.RenderedEmail baseRendered = renderOpportunityTemplate(
            firstOpportunity,
            templateName
        );
        if (baseRendered == null) {
            return false;
        }
        
        Set<String> recipients = resolveOpportunityRecipients(
            firstOpportunity,
            recipientType
        );
        if (recipients == null || recipients.isEmpty()) {
            return false;
        }
        
        // New object so a shared/test-override instance is never mutated.
        DealerOpportunityEmailService.RenderedEmail consolidated = new DealerOpportunityEmailService.RenderedEmail();
        
        String baseSubject = String.isBlank(baseRendered.subject)
            ? templateName
            : baseRendered.subject;
        consolidated.subject = baseSubject + ' (' + opportunityRecords.size() + ' Opportunities)';
        
        // CHANGE: "Regards" closing is split off the template body and placed AFTER the table.
        String rawHtml = String.isNotBlank(baseRendered.htmlBody)
            ? baseRendered.htmlBody
            : (String.isNotBlank(baseRendered.plainTextBody)
               ? baseRendered.plainTextBody.replace('\n', '<br/>')
               : '');
                   List<String> htmlParts = splitClosingHtml(rawHtml);
        
        consolidated.htmlBody =
            htmlParts[0] +
            '<br/><p><b>Opportunities requiring attention (' + opportunityRecords.size() + '):</b></p>' +
            buildConsolidatedOpportunityHtml(opportunityRecords, daysByOpportunityId) +
            '<br/>' + htmlParts[1];
        
        List<String> textParts = splitClosingText(baseRendered.plainTextBody);
        consolidated.plainTextBody =
            textParts[0] +
            '\n\nOpportunities requiring attention (' + opportunityRecords.size() + '):\n' +
            buildConsolidatedOpportunityText(opportunityRecords, daysByOpportunityId) +
            '\n\n' + textParts[1];
        
        return sendRenderedEmail(
            resolveOpportunityTargetObjectId(firstOpportunity),
            consolidated,
            recipients,
            buildConsolidatedSendKey(groupKey, templateName)
        );
    }
    
    // NEW: HTML table listing every opportunity of the group.
    private static String buildConsolidatedOpportunityHtml(
        List<Opportunity> opportunityRecords,
        Map<Id, Long> daysByOpportunityId
    ) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String html =
            '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;font-size:13px;">' +
            '<tr style="background:#f3f3f3;">' +
            '<th>#</th><th>Opportunity</th><th>Owner</th><th>Department</th><th>Days Since Last Activity</th>' +
            '</tr>';
        
        Integer rowNumber = 1;
        for (Opportunity opportunityRecord : opportunityRecords) {
            Long days = (daysByOpportunityId != null && daysByOpportunityId.containsKey(opportunityRecord.Id))
                ? daysByOpportunityId.get(opportunityRecord.Id)
                : 0;
            String oppName = String.isBlank(opportunityRecord.Name)
                ? String.valueOf(opportunityRecord.Id)
                : opportunityRecord.Name;
            String ownerName = opportunityRecord.Owner != null && opportunityRecord.Owner.Name != null
                ? opportunityRecord.Owner.Name
                : '';
            String department = String.isNotBlank(opportunityRecord.Department_NameFormula__c)
                ? opportunityRecord.Department_NameFormula__c
                : (opportunityRecord.Department_Name__c != null ? opportunityRecord.Department_Name__c : '');
                    
                    html +=
                    '<tr>' +
                    '<td>' + rowNumber + '</td>' +
                    '<td><a href="' + baseUrl + '/' + opportunityRecord.Id + '">' + oppName.escapeHtml4() + '</a></td>' +
                    '<td>' + ownerName.escapeHtml4() + '</td>' +
                    '<td>' + department.escapeHtml4() + '</td>' +
                    '<td>' + days + '</td>' +
                    '</tr>';
            rowNumber++;
        }
        return html + '</table>';
    }
    
    // NEW: plain-text version of the same list.
    private static String buildConsolidatedOpportunityText(
        List<Opportunity> opportunityRecords,
        Map<Id, Long> daysByOpportunityId
    ) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<String> lines = new List<String>();
        Integer rowNumber = 1;
        for (Opportunity opportunityRecord : opportunityRecords) {
            Long days = (daysByOpportunityId != null && daysByOpportunityId.containsKey(opportunityRecord.Id))
                ? daysByOpportunityId.get(opportunityRecord.Id)
                : 0;
            String department = String.isNotBlank(opportunityRecord.Department_NameFormula__c)
                ? opportunityRecord.Department_NameFormula__c
                : (opportunityRecord.Department_Name__c != null ? opportunityRecord.Department_Name__c : '');
                    lines.add(
                        rowNumber + '. ' + opportunityRecord.Name + ' | ' +
                        (opportunityRecord.Owner != null ? opportunityRecord.Owner.Name : '') + ' | ' +
                        department + ' | ' +
                        days + ' days | ' + baseUrl + '/' + opportunityRecord.Id
                    );
            rowNumber++;
        }
        return String.join(lines, '\n');
    }
    
    // =============================================================================
    // (next to the Lead / Opportunity consolidated methods you already added).
    // Nothing existing is modified. Reuses: resolveTemplateId, renderTaskTemplate,
    // resolveOpportunityTargetObjectId, sendRenderedEmail, buildConsolidatedSendKey and
    // wasConsolidatedSendSuccessful (already added with the Lead change).
    // =============================================================================
    
    /**
* @description NEW: One line of a consolidated Task-overdue email.
*              One row = one Lead OR one Opportunity, plus the overdue Task used for it.
*/
    public class TaskDigestRow {
        public Task taskRecord;
        public Lead leadRecord; // set when the row belongs to a Lead
        public Opportunity opportunityRecord; // set when the row belongs to an Opportunity
        public Long hoursSinceFirstOverdue;
    }
    
    /**
* @description NEW: Sends ONE consolidated Task-overdue email to one recipient group.
*              - Recipients are taken from groupKey (sorted emails joined by ';'),
*                which the batch built with the existing recipient logic.
*              - Subject / intro come from the existing Task template, rendered
*                against the first Task of the group (same as sendTaskRelatedEmail).
*              - A table listing ALL rows is appended to the body.
*              - The email is queued; the caller must call flushQueuedEmails().
*/
    public static Boolean sendConsolidatedTaskEmail(
        List<TaskDigestRow> rows,
        String templateName,
        String groupKey
    ) {
        if (
            rows == null ||
            rows.isEmpty() ||
            String.isBlank(templateName) ||
            String.isBlank(groupKey)
        ) {
            return false;
        }
        
        TaskDigestRow firstRow = rows[0];
        if (firstRow == null || firstRow.taskRecord == null || firstRow.taskRecord.Id == null) {
            return false;
        }
        
        Set<String> recipients = new Set<String>(groupKey.split(';'));
        if (recipients.isEmpty()) {
            return false;
        }
        
        // Base rendering (template merged against the first Task of the group).
        DealerOpportunityEmailService.RenderedEmail baseRendered;
        if (Test.isRunningTest() && testOppRenderedOverride != null) {
            baseRendered = testOppRenderedOverride;
        } else if (Test.isRunningTest() && testLeadRenderedOverride != null) {
            baseRendered = new DealerOpportunityEmailService.RenderedEmail();
            baseRendered.subject = testLeadRenderedOverride.subject;
            baseRendered.htmlBody = testLeadRenderedOverride.htmlBody;
            baseRendered.plainTextBody = testLeadRenderedOverride.plainTextBody;
        } else {
            Id templateId = resolveTemplateId(templateName);
            if (templateId == null) {
                return false;
            }
            baseRendered = renderTaskTemplate(templateId, firstRow.taskRecord);
            // NEW fallback: if the template cannot render (e.g. unresolved Task merge fields),
            // still send the consolidated table with a generic intro.
            if (baseRendered == null) {
                baseRendered = new DealerOpportunityEmailService.RenderedEmail();
                baseRendered.subject = templateName;
                
                Task firstTask = firstRow.taskRecord;
                
                Boolean isOwnerTier = templateName.toLowerCase().contains('owner');
String ownerName = (isOwnerTier && String.isNotBlank(taskRowOwnerName(firstRow)))
    ? taskRowOwnerName(firstRow)
    : 'Sir/Madam';
                
                String taskId = String.valueOf(firstTask.Id);
                
                String taskSubject = String.isNotBlank(firstTask.Subject)
                    ? firstTask.Subject
                    : '';
                
                String dueDate = firstTask.ActivityDate != null
                    ? firstTask.ActivityDate.format()
                    : 'N/A';
                
                baseRendered.htmlBody =
    '<p>Dear ' + ownerName.escapeHtml4() + ',</p>' +
    '<p>' + taskSubject.escapeHtml4() +
    ' was due on ' + dueDate.escapeHtml4() +
    ' and is currently overdue.</p>' +
    '<p>Please complete and update the status at the earliest, ' +
    'or flag any blockers to your reporting manager.</p>' +
    '<p>Regards,<br/>Team CRM</p>';

baseRendered.plainTextBody =
    'Dear ' + ownerName + ',\n\n' +
    taskSubject +
    ' was due on ' + dueDate +
    ' and is currently overdue.\n\n' +
    'Please complete and update the status at the earliest, ' +
    'or flag any blockers to your reporting manager.\n\n' +
    'Regards,\nTeam CRM';            }
        }
        if (baseRendered == null) {
            return false;
        }
        
        // New object so a shared/test-override instance is never mutated.
        DealerOpportunityEmailService.RenderedEmail consolidated = new DealerOpportunityEmailService.RenderedEmail();
        
        String baseSubject = String.isNotBlank(baseRendered.subject) ? baseRendered.subject : 'Action Required: Your Task is Overdue';
        
        consolidated.subject = baseSubject + ' (' + rows.size() + ' Tasks)';
        
        // CHANGE: "Regards" closing is split off the template body and placed AFTER the table.
        String rawHtml = String.isNotBlank(baseRendered.htmlBody)
            ? baseRendered.htmlBody
            : (String.isNotBlank(baseRendered.plainTextBody)
               ? baseRendered.plainTextBody.replace('\n', '<br/>')
               : '');
                   List<String> htmlParts = splitClosingHtml(rawHtml);
        
        consolidated.htmlBody =
            htmlParts[0] +
            '<br/><p><b>Overdue tasks (' + rows.size() + '):</b></p>' +
            buildConsolidatedTaskHtml(rows) +
            '<br/>' + htmlParts[1];
        
        List<String> textParts = splitClosingText(baseRendered.plainTextBody);
        consolidated.plainTextBody =
            textParts[0] +
            '\n\nOverdue tasks (' + rows.size() + '):\n' +
            buildConsolidatedTaskText(rows) +
            '\n\n' + textParts[1];
        
        // Same target-object rule as sendTaskRelatedEmail().
        Id targetObjectId = firstRow.leadRecord != null
            ? firstRow.leadRecord.Id
            : (firstRow.opportunityRecord != null
               ? resolveOpportunityTargetObjectId(firstRow.opportunityRecord)
               : firstRow.taskRecord.OwnerId);
                   
                   return sendRenderedEmail(
                       targetObjectId,
                       consolidated,
                       recipients,
                       buildConsolidatedSendKey(groupKey, templateName)
                   );
    }
    
    // NEW: small accessors so the table builders stay readable.
    private static String taskRowRelatedType(TaskDigestRow row) {
        return row.leadRecord != null ? 'Lead' : 'Opportunity';
    }
    
    private static Id taskRowRelatedId(TaskDigestRow row) {
        return row.leadRecord != null ? row.leadRecord.Id : row.opportunityRecord.Id;
    }
    
    private static String taskRowRelatedName(TaskDigestRow row) {
        String name = row.leadRecord != null ? row.leadRecord.Name : row.opportunityRecord.Name;
        return String.isBlank(name) ? String.valueOf(taskRowRelatedId(row)) : name;
    }
    
    private static String taskRowOwnerName(TaskDigestRow row) {
        if (row.leadRecord != null) {
            return row.leadRecord.Owner != null && row.leadRecord.Owner.Name != null
                ? row.leadRecord.Owner.Name
                : '';
        }
        return row.opportunityRecord.Owner != null && row.opportunityRecord.Owner.Name != null
            ? row.opportunityRecord.Owner.Name
            : '';
    }
    
    private static String taskRowDepartment(TaskDigestRow row) {
        if (row.leadRecord != null) {
            return row.leadRecord.Department_NameFormula__c != null
                ? row.leadRecord.Department_NameFormula__c
                : '';
        }
        return String.isNotBlank(row.opportunityRecord.Department_NameFormula__c)
            ? row.opportunityRecord.Department_NameFormula__c
            : (row.opportunityRecord.Department_Name__c != null
               ? row.opportunityRecord.Department_Name__c
               : '');
                   }
    
    // NEW: HTML table listing every overdue task of the group.
    private static String buildConsolidatedTaskHtml(List<TaskDigestRow> rows) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String html =
            '<table border="1" cellpadding="6" cellspacing="0" style="border-collapse:collapse;font-size:13px;">' +
            '<tr style="background:#f3f3f3;">' +
            '<th>#</th><th>Related To</th><th>Task</th><th>Due Date</th><th>Owner</th><th>Department</th><th>Hours Since First Overdue</th>' +
            '</tr>';
        
        Integer rowNumber = 1;
        for (TaskDigestRow row : rows) {
            if (row == null || row.taskRecord == null) {
                continue;
            }
            if (row.leadRecord == null && row.opportunityRecord == null) {
                continue;
            }
            
            String subject = String.isBlank(row.taskRecord.Subject) ? '' : row.taskRecord.Subject;
            String dueDate = row.taskRecord.ActivityDate != null ? row.taskRecord.ActivityDate.format() : '';
            Long hours = row.hoursSinceFirstOverdue != null ? row.hoursSinceFirstOverdue : 0;
            
            html +=
                '<tr>' +
                '<td>' + rowNumber + '</td>' +
                '<td>' + taskRowRelatedType(row) + ': <a href="' + baseUrl + '/' + taskRowRelatedId(row) + '">' +
                taskRowRelatedName(row).escapeHtml4() + '</a></td>' +
                '<td><a href="' + baseUrl + '/' + row.taskRecord.Id + '">' + subject.escapeHtml4() + '</a></td>' +
                '<td>' + dueDate + '</td>' +
                '<td>' + taskRowOwnerName(row).escapeHtml4() + '</td>' +
                '<td>' + taskRowDepartment(row).escapeHtml4() + '</td>' +
                '<td>' + hours + '</td>' +
                '</tr>';
            rowNumber++;
        }
        return html + '</table>';
    }
    
    // NEW: plain-text version of the same list.
    private static String buildConsolidatedTaskText(List<TaskDigestRow> rows) {
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        List<String> lines = new List<String>();
        Integer rowNumber = 1;
        for (TaskDigestRow row : rows) {
            if (row == null || row.taskRecord == null) {
                continue;
            }
            if (row.leadRecord == null && row.opportunityRecord == null) {
                continue;
            }
            lines.add(
                rowNumber + '. ' + taskRowRelatedType(row) + ': ' + taskRowRelatedName(row) + ' | ' +
                row.taskRecord.Subject + ' | due ' +
                (row.taskRecord.ActivityDate != null ? row.taskRecord.ActivityDate.format() : '') + ' | ' +
                taskRowOwnerName(row) + ' | ' + taskRowDepartment(row) + ' | ' +
                (row.hoursSinceFirstOverdue != null ? row.hoursSinceFirstOverdue : 0) + ' hrs | ' +
                baseUrl + '/' + taskRowRelatedId(row)
            );
            rowNumber++;
        }
        return String.join(lines, '\n');
    }
}