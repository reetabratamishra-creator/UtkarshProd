/**
 * CaseCreationController
 * Server side for the caseCreationForm LWC (Case list-view "New Complaint" button).
 *
 * Flow: department -> account OR opportunity -> contacts -> createCase(), which also
 * attaches any files the browser has already uploaded. Cases are created under the
 * "Case" record type, resolved by developer name at runtime.
 * createCase() inserts the Case, links every selected contact through Case_Contacts__c,
 * fires the custom push notification to the assignee, and emails every linked contact
 * that has an email address.
 *
 * Files: lightning-file-upload stages them against the running user's own record, so the
 * bytes go straight to Salesforce's file service and never pass through Apex. attachFiles()
 * then relinks those documents to the saved case. This is what makes 25 MB (and video)
 * possible on a single screen - base64 through Apex tops out near 4 MB against the 6 MB
 * heap limit, since base64 inflates by about a third.
 */
public with sharing class CaseCreationController {

    private static final String NOTIFICATION_TYPE_NAME = 'Case_Creation_Push_Notification';
    private static final String EMAIL_TEMPLATE_NAME     = 'Case Creation Template';
    private static final String ORG_WIDE_EMAIL          = 'noreply@utkarshindialimited.in';
    private static final String DEFAULT_STATUS          = 'Open';
    private static final String RECORD_TYPE_NAME        = 'Case';

    /**
     * Department values the intake form must not offer. "Enquiry" exists for the
     * before-save flow's own use, not for a complaint being raised by hand.
     */
    private static final Set<String> HIDDEN_DEPARTMENTS = new Set<String>{ 'enquiry' };

    // ------------------------------------------------------------------
    // Wrappers
    // ------------------------------------------------------------------
    public class CaseRequest {
        @AuraEnabled public String accountId     { get; set; }
        @AuraEnabled public String opportunityId { get; set; }
        /** Every contact the user ticked - written to Case_Contacts__c, not to Case.ContactId. */
        @AuraEnabled public List<String> contactIds { get; set; }
        @AuraEnabled public String department    { get; set; }
        @AuraEnabled public String subDepartment { get; set; }
        @AuraEnabled public String origin        { get; set; }  // Source of Complaint
        @AuraEnabled public String caseType      { get; set; }  // Category of Complaint
        @AuraEnabled public String subCategory   { get; set; }
        @AuraEnabled public String priority      { get; set; }
        @AuraEnabled public String subject       { get; set; }
        @AuraEnabled public String description   { get; set; }
        @AuraEnabled public String comments      { get; set; }  // Internal Comments
        @AuraEnabled public String assignedToId  { get; set; }
        @AuraEnabled public String customerName  { get; set; }
        /** ContentDocumentIds already uploaded by the browser. */
        @AuraEnabled public List<String> documentIds { get; set; }
    }

    public class CaseResult {
        @AuraEnabled public Id caseId              { get; set; }
        @AuraEnabled public String caseNumber      { get; set; }
        @AuraEnabled public Id ownerId             { get; set; }
        @AuraEnabled public Boolean ownerChanged   { get; set; }
        @AuraEnabled public Integer contactsLinked { get; set; }
        @AuraEnabled public Integer filesAttached  { get; set; }
        @AuraEnabled public Integer emailsSent     { get; set; }
        @AuraEnabled public String warning         { get; set; }
    }

    public class Option {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        /** Controlling values this entry is valid for. Empty for independent picklists. */
        @AuraEnabled public List<String> validFor { get; set; }
        public Option(String label, String value) {
            this.label = label;
            this.value = value;
            this.validFor = new List<String>();
        }
    }

    public class PicklistField {
        @AuraEnabled public String fieldApiName  { get; set; }
        @AuraEnabled public String label         { get; set; }
        @AuraEnabled public List<Option> options { get; set; }
        /** Populated only when something is wrong - surfaced in the UI, never swallowed. */
        @AuraEnabled public String diagnostic    { get; set; }
        public PicklistField(String fieldApiName) {
            this.fieldApiName = fieldApiName;
            this.label = fieldApiName;
            this.options = new List<Option>();
        }
    }

    public class ContactOption {
        @AuraEnabled public String value      { get; set; }  // datatable key-field
        @AuraEnabled public String label      { get; set; }
        @AuraEnabled public String name       { get; set; }
        @AuraEnabled public String phone      { get; set; }
        @AuraEnabled public String email      { get; set; }
        /** Primary opportunity contact role - preselected in the table. */
        @AuraEnabled public Boolean isPrimary { get; set; }
        @AuraEnabled public String role       { get; set; }
    }

    /** Everything the form needs once an opportunity is picked. */
    public class OpportunityContext {
        @AuraEnabled public String accountId   { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public List<ContactOption> contacts { get; set; }
        /** Ids to tick on load - the primary contact role, when there is one. */
        @AuraEnabled public List<String> preselectedIds { get; set; }
        public OpportunityContext() {
            this.contacts = new List<ContactOption>();
            this.preselectedIds = new List<String>();
        }
    }

    // ------------------------------------------------------------------
    // Picklists
    // ------------------------------------------------------------------
    private static final List<String> FORM_PICKLISTS = new List<String>{
        'Department__c', 'Sub_Department__c', 'Origin', 'Type', 'Sub_Category__c', 'Priority'
    };

    private static final String HEX_DIGITS = '0123456789ABCDEF';

    /**
     * Every picklist the form needs, as a list rather than a map so nothing depends
     * on how Apex serialises map keys.
     *
     * Check what this actually returns with:
     *   System.debug(JSON.serializePretty(CaseCreationController.getFormPicklists()));
     */
    @AuraEnabled(cacheable=true)
    public static List<PicklistField> getFormPicklists() {
        List<PicklistField> fields = new List<PicklistField>();
        for (String fieldApiName : FORM_PICKLISTS) {
            fields.add(describePicklist(fieldApiName));
        }
        return fields;
    }

    private static PicklistField describePicklist(String fieldApiName) {
        PicklistField result = new PicklistField(fieldApiName);
        try {
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
            Schema.SObjectField token = fieldMap.get(fieldApiName);
            if (token == null) {
                token = fieldMap.get(fieldApiName.toLowerCase());
            }
            if (token == null) {
                result.diagnostic = 'field not found on Case';
                return result;
            }

            Schema.DescribeFieldResult dfr = token.getDescribe();
            result.label = dfr.getLabel();

            List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
            if (entries.isEmpty()) {
                result.diagnostic = 'no picklist values returned by describe (field type: '
                    + dfr.getType() + ')';
                return result;
            }

            // Controlling field, if this is a dependent picklist.
            List<String> controllingValues = new List<String>();
            Schema.SObjectField controller = dfr.getController();
            if (controller != null) {
                for (Schema.PicklistEntry entry : controller.getDescribe().getPicklistValues()) {
                    if (entry.isActive()) {
                        controllingValues.add(entry.getValue());
                    }
                }
            }

            for (Schema.PicklistEntry entry : entries) {
                if (!entry.isActive()) {
                    continue;
                }
                // Suppressed for the form only - the value stays valid on the record.
                if (fieldApiName.equalsIgnoreCase('Department__c')
                        && HIDDEN_DEPARTMENTS.contains(entry.getValue().toLowerCase())) {
                    continue;
                }
                Option option = new Option(entry.getLabel(), entry.getValue());
                if (!controllingValues.isEmpty()) {
                    option.validFor = decodeValidFor(entry, controllingValues);
                }
                result.options.add(option);
            }

            if (result.options.isEmpty()) {
                result.diagnostic = 'every value on this picklist is inactive';
            } else if (!dfr.isAccessible()) {
                result.diagnostic = 'hidden by field-level security for your profile';
            }
        } catch (Exception e) {
            result.diagnostic = 'describe failed: ' + e.getMessage();
        }
        return result;
    }

    /**
     * PicklistEntry.validFor is a base64 bitset that describe does not expose
     * directly, so it is read back off the serialised entry and unpacked.
     */
    private static List<String> decodeValidFor(Schema.PicklistEntry entry, List<String> controllingValues) {
        List<String> valid = new List<String>();
        String encoded;
        try {
            Map<String, Object> raw =
                (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(entry));
            encoded = (String) raw.get('validFor');
        } catch (Exception e) {
            return valid; // treat as independent rather than losing the whole picklist
        }
        if (String.isBlank(encoded)) {
            return valid;
        }
        String hex = EncodingUtil.convertToHex(EncodingUtil.base64Decode(encoded)).toUpperCase();
        for (Integer i = 0; i < hex.length() / 2; i++) {
            Integer octet = HEX_DIGITS.indexOf(hex.substring(i * 2, i * 2 + 1)) * 16
                          + HEX_DIGITS.indexOf(hex.substring(i * 2 + 1, i * 2 + 2));
            for (Integer bit = 0; bit < 8; bit++) {
                Integer index = (i * 8) + bit;
                if (index >= controllingValues.size()) {
                    break;
                }
                if ((octet & (128 >> bit)) != 0) {
                    valid.add(controllingValues[index]);
                }
            }
        }
        return valid;
    }

    // ------------------------------------------------------------------
    // Contacts
    // ------------------------------------------------------------------

    /** Contacts sitting under the chosen account. */
    @AuraEnabled(cacheable=true)
    public static List<ContactOption> getContactsForAccount(Id accountId) {
        List<ContactOption> options = new List<ContactOption>();
        if (accountId == null) {
            return options;
        }
        for (Contact c : [
            SELECT Id, Name, Phone, Email
            FROM Contact
            WHERE AccountId = :accountId
            WITH SYSTEM_MODE
            ORDER BY Name
            LIMIT 500
        ]) {
            options.add(toOption(c, false, null));
        }
        return options;
    }

    /**
     * Contacts for an opportunity: everyone under the opportunity's account, with the
     * primary opportunity contact role flagged so the form can tick it on load.
     * Contact roles pointing at a contact outside that account are appended too.
     */
    @AuraEnabled(cacheable=true)
    public static OpportunityContext getOpportunityContext(Id opportunityId) {
        OpportunityContext context = new OpportunityContext();
        if (opportunityId == null) {
            return context;
        }

        List<Opportunity> opps = [
            SELECT Id, AccountId, Account.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            throw new AuraHandledException('That opportunity could not be read.');
        }
        Opportunity opp = opps[0];
        if (opp.AccountId == null) {
            throw new AuraHandledException('This opportunity has no account, so contacts cannot be listed.');
        }
        context.accountId   = opp.AccountId;
        context.accountName = opp.Account.Name;

        // Roles first, so primary/role labels are known before listing account contacts.
        Map<Id, OpportunityContactRole> rolesByContact = new Map<Id, OpportunityContactRole>();
        for (OpportunityContactRole ocr : [
            SELECT ContactId, IsPrimary, Role, Contact.Name, Contact.Phone, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :opportunityId
            WITH SYSTEM_MODE
            LIMIT 500
        ]) {
            rolesByContact.put(ocr.ContactId, ocr);
            if (ocr.IsPrimary == true) {
                context.preselectedIds.add(String.valueOf(ocr.ContactId));
            }
        }

        Set<Id> listed = new Set<Id>();
        for (Contact c : [
            SELECT Id, Name, Phone, Email
            FROM Contact
            WHERE AccountId = :opp.AccountId
            WITH SYSTEM_MODE
            ORDER BY Name
            LIMIT 500
        ]) {
            OpportunityContactRole ocr = rolesByContact.get(c.Id);
            Boolean isPrimary = (ocr != null && ocr.IsPrimary == true);
            String role = (ocr == null) ? null : ocr.Role;
            context.contacts.add(toOption(c, isPrimary, role));
            listed.add(c.Id);
        }

        // Contact roles whose contact hangs off a different account.
        for (OpportunityContactRole ocr : rolesByContact.values()) {
            if (listed.contains(ocr.ContactId) || ocr.Contact == null) {
                continue;
            }
            context.contacts.add(toOption(ocr.Contact, ocr.IsPrimary == true, ocr.Role));
        }
        return context;
    }

    /**
     * Adds a contact so intake isn't blocked by a missing one. In opportunity mode the
     * caller passes the opportunity and the contact is created under its account.
     */
    @AuraEnabled
    public static ContactOption createContact(Id accountId, Id opportunityId, String firstName,
                                              String lastName, String phone, String email) {
        Id targetAccountId = accountId;
        if (targetAccountId == null && opportunityId != null) {
            List<Opportunity> opps = [
                SELECT AccountId FROM Opportunity WHERE Id = :opportunityId WITH SYSTEM_MODE LIMIT 1
            ];
            targetAccountId = opps.isEmpty() ? null : opps[0].AccountId;
        }
        if (targetAccountId == null) {
            throw new AuraHandledException('Select an account or an opportunity before adding a contact.');
        }
        if (String.isBlank(lastName)) {
            throw new AuraHandledException('Enter a last name for the contact.');
        }

        Contact c = new Contact(
            AccountId = targetAccountId,
            FirstName = firstName,
            LastName  = lastName,
            Phone     = phone,
            Email     = email
        );
        try {
            insert c;
        } catch (DmlException e) {
            throw new AuraHandledException('The contact could not be saved: ' + e.getDmlMessage(0));
        }
        return toOption(
            [SELECT Id, Name, Phone, Email FROM Contact WHERE Id = :c.Id LIMIT 1],
            false,
            null
        );
    }

    private static ContactOption toOption(Contact c, Boolean isPrimary, String role) {
        ContactOption o = new ContactOption();
        o.value     = c.Id;
        o.label     = c.Name + (String.isBlank(c.Email) ? '' : ' (' + c.Email + ')');
        o.name      = c.Name;
        o.phone     = c.Phone;   // Business Phone
        o.email     = c.Email;
        o.isPrimary = (isPrimary == true);
        o.role      = role;
        return o;
    }

    /**
     * Active users whose User.Department CONTAINS the selected case department
     * (one user can carry multiple departments in that field).
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getUsersByDepartment(String department) {
        List<Option> options = new List<Option>();
        if (String.isBlank(department)) {
            return options;
        }
        // Neutralise SOQL LIKE wildcards coming from the picklist value itself.
        String term = '%' + department.replace('\\', '\\\\')
                                      .replace('%', '\\%')
                                      .replace('_', '\\_') + '%';
        for (User u : [
            SELECT Id, Name, Department
            FROM User
            WHERE IsActive = TRUE
              AND Department LIKE :term
            WITH SYSTEM_MODE
            ORDER BY Name
            LIMIT 500
        ]) {
            // Name only - the department is already chosen above the picker, so
            // repeating it in every row is noise.
            options.add(new Option(u.Name, u.Id));
        }
        return options;
    }

    // ------------------------------------------------------------------
    // Create
    // ------------------------------------------------------------------
    @AuraEnabled
    public static CaseResult createCase(CaseRequest req) {
        if (req == null) {
            throw new AuraHandledException('No case details were received.');
        }
        if (String.isBlank(req.subject)) {
            throw new AuraHandledException('Enter a subject for the case.');
        }
        if (String.isBlank(req.accountId) && String.isBlank(req.opportunityId)) {
            throw new AuraHandledException('Select the account or opportunity the complaint relates to.');
        }

        // The account is resolved server side so the case is stamped correctly even
        // when the user picked an opportunity.
        Id accountId = String.isBlank(req.accountId) ? null : (Id) req.accountId;
        if (String.isNotBlank(req.opportunityId)) {
            List<Opportunity> opps = [
                SELECT AccountId FROM Opportunity WHERE Id = :req.opportunityId WITH SYSTEM_MODE LIMIT 1
            ];
            if (!opps.isEmpty() && opps[0].AccountId != null) {
                accountId = opps[0].AccountId;
            }
        }

        Id ownerId = UserInfo.getUserId();
        if (String.isNotBlank(req.assignedToId)) {
            try {
                ownerId = Id.valueOf(req.assignedToId.trim());
            } catch (Exception e) {
                throw new AuraHandledException('The selected assignee is not a valid user.');
            }
        }

        // ContactId is deliberately not set - contacts live on Case_Contacts__c now,
        // which is also why ContactPhone / ContactEmail are left alone.
        Case newCase = new Case(
            RecordTypeId = caseRecordTypeId(),
            AccountId   = accountId,
            Status      = DEFAULT_STATUS,
            Origin      = req.origin,
            Type        = req.caseType,
            Priority    = req.priority,
            Subject     = req.subject,
            Description = req.description,
            OwnerId     = ownerId
        );

        // Fields that may be read-only or absent depending on the org, so set
        // them only when the running user can actually write them.
        List<String> skipped = new List<String>();
        putIfCreateable(newCase, 'Department__c',      req.department,    skipped);
        putIfCreateable(newCase, 'Sub_Department__c',  req.subDepartment, skipped);
        putIfCreateable(newCase, 'Sub_Category__c',    req.subCategory,   skipped);
        putIfCreateable(newCase, 'Customer_Name__c',   req.customerName,  skipped);
        putIfCreateable(newCase, 'Opportunity__c',     req.opportunityId, skipped);
        // Writing Case.Comments on insert files a Case Comment record.
        putIfCreateable(newCase, 'Comments',           req.comments,      skipped);

        if (newCase.OwnerId == null) {
            newCase.OwnerId = UserInfo.getUserId();
        }

        System.debug('Owner Id is ' + newCase.OwnerId);

        try {
            insert newCase;
        } catch (DmlException e) {
            throw new AuraHandledException('The case could not be saved: ' + e.getDmlMessage(0));
        }

        Case saved = [
            SELECT Id, CaseNumber, OwnerId, Subject, Priority, Type, Origin
            FROM Case
            WHERE Id = :newCase.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        CaseResult result = new CaseResult();
        result.caseId         = saved.Id;
        result.caseNumber     = saved.CaseNumber;
        result.ownerId        = saved.OwnerId;
        result.ownerChanged   = (saved.OwnerId != UserInfo.getUserId());
        result.contactsLinked = linkContacts(saved.Id, req.contactIds);

        List<String> warnings = new List<String>();
        if (!skipped.isEmpty()) {
            warnings.add('These fields are not writable in this org and were skipped: '
                + String.join(skipped, ', ') + '.');
        }

        // The case exists by now, so a file problem is reported rather than thrown -
        // losing the case over an attachment would be the worse outcome.
        try {
            result.filesAttached = attachFiles(saved.Id, req.documentIds);
        } catch (Exception e) {
            result.filesAttached = 0;
            warnings.add('The case was created but the files could not be attached. '
                + 'They are in your personal Files.');
        }

        sendPushNotification(saved);
        result.emailsSent = sendCaseCreationEmails(saved, req.contactIds);

        if (!warnings.isEmpty()) {
            result.warning = String.join(warnings, ' ');
        }
        return result;
    }

    /**
     * Record type id for complaints, looked up by developer name rather than hard-coded -
     * ids differ between sandbox and production, so a literal breaks on first deployment.
     */
    @TestVisible
    private static Id caseRecordTypeId() {
        List<RecordType> types = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Case'
              AND DeveloperName = :RECORD_TYPE_NAME
              AND IsActive = TRUE
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (types.isEmpty()) {
            throw new AuraHandledException(
                'The "' + RECORD_TYPE_NAME + '" record type could not be found on Case, '
                + 'or it is inactive. Complaints cannot be raised without it.'
            );
        }
        return types[0].Id;
    }

    /** Writes the Case <-> Contact junction rows. */
    private static Integer linkContacts(Id caseId, List<String> contactIds) {
        Set<Id> unique = toIdSet(contactIds);
        if (unique.isEmpty()) {
            return 0;
        }
        List<Case_Contacts__c> links = new List<Case_Contacts__c>();
        for (Id contactId : unique) {
            links.add(new Case_Contacts__c(Case__c = caseId, Contact__c = contactId));
        }
        try {
            insert links;
        } catch (DmlException e) {
            // The case already exists, so surface this rather than losing it silently.
            throw new AuraHandledException(
                'The case was created but the contacts could not be linked: ' + e.getDmlMessage(0)
            );
        }
        return links.size();
    }

    private static Set<Id> toIdSet(List<String> rawIds) {
        Set<Id> ids = new Set<Id>();
        if (rawIds == null) {
            return ids;
        }
        for (String raw : rawIds) {
            if (String.isBlank(raw)) {
                continue;
            }
            try {
                ids.add(Id.valueOf(raw.trim()));
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Ignoring invalid contact id: ' + raw);
            }
        }
        return ids;
    }

    // ------------------------------------------------------------------
    // Files
    // ------------------------------------------------------------------
    /**
     * Moves already-uploaded documents onto the case.
     *
     * lightning-file-upload streams the bytes straight to Salesforce against the running
     * user's own record, so nothing large ever reaches Apex. This adds a link to the case,
     * drops the staging link, and hands ownership to the case owner when that differs.
     */
    @TestVisible
    private static Integer attachFiles(Id caseId, List<String> documentIds) {
        Set<Id> docIds = toIdSet(documentIds);
        if (caseId == null || docIds.isEmpty()) {
            return 0;
        }

        List<Case> cases = [SELECT OwnerId FROM Case WHERE Id = :caseId WITH SYSTEM_MODE LIMIT 1];
        if (cases.isEmpty()) {
            return 0;
        }
        Id ownerId = cases[0].OwnerId;

        // Skip anything already linked, so a retry cannot create duplicate links.
        Set<Id> alreadyLinked = new Set<Id>();
        for (ContentDocumentLink existing : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId AND ContentDocumentId IN :docIds
            WITH SYSTEM_MODE
        ]) {
            alreadyLinked.add(existing.ContentDocumentId);
        }

        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for (Id docId : docIds) {
            if (alreadyLinked.contains(docId)) {
                continue;
            }
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId    = caseId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ));
        }
        if (!newLinks.isEmpty()) {
            insert newLinks;
        }

        removeStagingLinks(docIds);
        transferOwnership(docIds, ownerId);
        return newLinks.size();
    }

    /**
     * Deletes the link to the uploader's own record that lightning-file-upload created,
     * so the file lives on the case rather than in personal files as well.
     */
    private static void removeStagingLinks(Set<Id> docIds) {
        List<ContentDocumentLink> staging = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :docIds
              AND LinkedEntityId = :UserInfo.getUserId()
            WITH SYSTEM_MODE
        ];
        if (staging.isEmpty()) {
            return;
        }
        try {
            delete staging;
        } catch (DmlException e) {
            // The file is on the case either way; it just also stays in personal files.
            System.debug(LoggingLevel.WARN, 'Staging link cleanup failed: ' + e.getDmlMessage(0));
        }
    }

    /** Hands documents to the case owner when the uploader is somebody else. */
    private static void transferOwnership(Set<Id> docIds, Id ownerId) {
        // A queue can own a case but cannot own a document.
        if (ownerId == null || String.valueOf(ownerId).startsWith('00G')) {
            return;
        }
        List<ContentDocument> toMove = new List<ContentDocument>();
        for (ContentDocument doc : [
            SELECT Id, OwnerId FROM ContentDocument WHERE Id IN :docIds WITH SYSTEM_MODE
        ]) {
            if (doc.OwnerId != ownerId) {
                toMove.add(new ContentDocument(Id = doc.Id, OwnerId = ownerId));
            }
        }
        if (toMove.isEmpty()) {
            return;
        }
        try {
            update toMove;
        } catch (DmlException e) {
            // The files are attached and usable; only the owner is wrong.
            System.debug(LoggingLevel.ERROR, 'File ownership transfer failed: ' + e.getDmlMessage(0));
        }
    }

    /** Discards a staged file when the user removes it before saving the case. */
    @AuraEnabled
    public static void discardFile(Id documentId) {
        if (documentId == null) {
            return;
        }
        try {
            delete [SELECT Id FROM ContentDocument WHERE Id = :documentId WITH SYSTEM_MODE LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('That file could not be removed: ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------------
    // Notification + email
    // ------------------------------------------------------------------
    @TestVisible
    private static void sendPushNotification(Case c) {
        try {
            List<CustomNotificationType> types = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_TYPE_NAME
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (types.isEmpty()) {
                return;
            }
            Messaging.CustomNotification note = new Messaging.CustomNotification();
            note.setNotificationTypeId(types[0].Id);
            note.setTargetId(c.Id);
            note.setTitle('New case assigned: ' + c.CaseNumber);
            note.setBody(
                (String.isBlank(c.Priority) ? '' : c.Priority + ' priority. ') +
                (String.isBlank(c.Subject) ? 'A case has been assigned to you.' : c.Subject)
            );
            note.send(new Set<String>{ String.valueOf(c.OwnerId) });
        } catch (Exception e) {
            // A failed notification must not roll back the case.
            System.debug(LoggingLevel.ERROR, 'Push notification failed: ' + e.getMessage());
        }
    }

    /** One templated email per linked contact that has an email address. */
    @TestVisible
    private static Integer sendCaseCreationEmails(Case c, List<String> contactIds) {
        Set<Id> ids = toIdSet(contactIds);
        if (ids.isEmpty()) {
            return 0;
        }
        try {
            List<EmailTemplate> templates = [
                SELECT Id
                FROM EmailTemplate
                WHERE Name = :EMAIL_TEMPLATE_NAME
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (templates.isEmpty()) {
                return 0;
            }

            List<Contact> recipients = [
                SELECT Id, Email
                FROM Contact
                WHERE Id IN :ids
                  AND Email != NULL
                WITH SYSTEM_MODE
            ];
            if (recipients.isEmpty()) {
                return 0;
            }

            List<OrgWideEmailAddress> owea = [
                SELECT Id FROM OrgWideEmailAddress WHERE Address = :ORG_WIDE_EMAIL LIMIT 1
            ];

            List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
            for (Contact recipient : recipients) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTemplateId(templates[0].Id);
                // Target is the contact, so the template merges that contact's details
                // and the mail goes to their own address.
                mail.setTargetObjectId(recipient.Id);
                mail.setWhatId(c.Id);
                mail.setSaveAsActivity(false);
                if (!owea.isEmpty()) {
                    mail.setOrgWideEmailAddressId(owea[0].Id);
                }
                messages.add(mail);
            }
            Messaging.sendEmail(messages, false);
            return messages.size();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Case creation email failed: ' + e.getMessage());
            return 0;
        }
    }

    // ------------------------------------------------------------------
    // Helper
    // ------------------------------------------------------------------
    private static void putIfCreateable(Case c, String fieldApiName, Object value, List<String> skipped) {
        if (value == null || (value instanceof String && String.isBlank((String) value))) {
            return;
        }
        Schema.SObjectField token = Schema.SObjectType.Case.fields.getMap().get(fieldApiName);
        if (token == null) {
            skipped.add(fieldApiName + ' (not found)');
            return;
        }
        Schema.DescribeFieldResult dfr = token.getDescribe();
        if (!dfr.isCreateable()) {
            skipped.add(dfr.getLabel() + ' (read-only)');
            return;
        }
        try {
            // sObject.put is strictly typed: a lookup needs an Id, not the String the
            // browser sent, or it throws "Illegal assignment from String to Id".
            if (dfr.getType() == Schema.DisplayType.REFERENCE && value instanceof String) {
                c.put(fieldApiName, Id.valueOf(((String) value).trim()));
            } else {
                c.put(fieldApiName, value);
            }
        } catch (Exception e) {
            skipped.add(dfr.getLabel() + ' (' + e.getMessage() + ')');
        }
    }
}