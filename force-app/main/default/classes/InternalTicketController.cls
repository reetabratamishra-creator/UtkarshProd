/**
 * InternalTicketController
 * Server side for the internalTicketForm LWC.
 *
 * The user picks a module from Internal_Ticket_Matrix__c. That record's L1 owner
 * becomes the case owner; the module name is stored on Case.Complaint_Category__c.
 * Tickets are created under the "Internal_Ticket" record type, resolved by developer
 * name at runtime. On save the L1 user gets a push notification and an email.
 *
 * Department defaults to the running user's own User.Department when that resolves to
 * exactly one valid picklist value; otherwise the form leaves it open.
 *
 * Files are uploaded by lightning-file-upload against the running user's own record,
 * so the bytes go straight to Salesforce's file service and never pass through Apex -
 * that is what allows 25 MB and video. attachFiles() then relinks them to the ticket.
 *
 * Every query runs in system mode: static SOQL uses WITH SYSTEM_MODE, and the one
 * dynamic query uses Database.query(soql, AccessLevel.SYSTEM_MODE), which is the
 * dynamic-SOQL equivalent.
 */
public with sharing class InternalTicketController {

    private static final String NOTIFICATION_TYPE_NAME = 'Case_Creation_Push_Notification';
    private static final String ORG_WIDE_EMAIL         = 'noreply@utkarshindialimited.in';
    private static final String DEFAULT_STATUS         = 'Open';
    private static final String RECORD_TYPE_NAME       = 'Internal_Ticket';
    private static final String MATRIX_OBJECT          = 'Internal_Ticket_Matrix__c';
    private static final String L1_FIELD               = 'L1__c';

    // ------------------------------------------------------------------
    // Wrappers
    // ------------------------------------------------------------------
    public class TicketRequest {
        /** Id of the Internal_Ticket_Matrix__c row - the module is re-read from it. */
        @AuraEnabled public String moduleId    { get; set; }
        @AuraEnabled public String department  { get; set; }
        @AuraEnabled public String priority    { get; set; }
        @AuraEnabled public String subject     { get; set; }
        @AuraEnabled public String description { get; set; }
        /** ContentDocumentIds already uploaded by the browser. */
        @AuraEnabled public List<String> documentIds { get; set; }
    }

    public class TicketResult {
        @AuraEnabled public Id caseId            { get; set; }
        @AuraEnabled public String caseNumber    { get; set; }
        @AuraEnabled public Id ownerId           { get; set; }
        @AuraEnabled public String ownerName     { get; set; }
        @AuraEnabled public Boolean emailSent    { get; set; }
        @AuraEnabled public Integer filesAttached { get; set; }
        @AuraEnabled public String warning       { get; set; }
    }

    public class ModuleOption {
        @AuraEnabled public String value      { get; set; }  // matrix record id
        @AuraEnabled public String label      { get; set; }  // module name
        @AuraEnabled public String l1UserId   { get; set; }
        @AuraEnabled public String l1UserName { get; set; }
        @AuraEnabled public String l1Email    { get; set; }
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

    /** What the form needs to decide whether Department is locked or open. */
    public class UserContext {
        /** Raw User.Department, for display when nothing could be matched. */
        @AuraEnabled public String rawDepartment { get; set; }
        /** The single matching Department__c value, or null when there isn't exactly one. */
        @AuraEnabled public String department    { get; set; }
        /** True when the field should be read-only. */
        @AuraEnabled public Boolean locked       { get; set; }
        /** Set when the field stays open despite the user having a department. */
        @AuraEnabled public String note          { get; set; }
        /** The raiser's own details, so the form can show who is logging the ticket. */
        @AuraEnabled public String userId        { get; set; }
        @AuraEnabled public String userName      { get; set; }
        @AuraEnabled public String userPhone     { get; set; }
        @AuraEnabled public String userEmail     { get; set; }
    }

    // ------------------------------------------------------------------
    // Running user
    // ------------------------------------------------------------------
    /**
     * Resolves the running user's department against the Case Department__c picklist.
     *
     * User.Department is free text and often holds several values (for example
     * "Sales;Service;Logistics"), so the field is locked only when exactly one valid
     * picklist value can be matched. Zero matches or several leaves the form open
     * rather than writing a value the user did not choose.
     */
    @AuraEnabled(cacheable=true)
    public static UserContext getUserContext() {
        UserContext context = new UserContext();
        context.locked = false;

        User me = runningUser();
        if (me != null) {
            context.userId    = me.Id;
            context.userName  = me.Name;
            // Phone is the desk number; MobilePhone is the fallback people actually answer.
            context.userPhone = String.isNotBlank(me.Phone) ? me.Phone : me.MobilePhone;
            context.userEmail = me.Email;
        }
        if (me == null || String.isBlank(me.Department)) {
            return context;
        }
        context.rawDepartment = me.Department;

        // Valid picklist values, lower-cased for matching.
        Map<String, String> valuesByKey = new Map<String, String>();
        Schema.SObjectField token = Schema.SObjectType.Case.fields.getMap().get('Department__c');
        if (token == null) {
            context.note = 'Department__c does not exist on Case.';
            return context;
        }
        for (Schema.PicklistEntry entry : token.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                valuesByKey.put(entry.getValue().toLowerCase(), entry.getValue());
            }
        }

        // Split on the separators people actually use in that field.
        Set<String> matched = new Set<String>();
        for (String part : context.rawDepartment.split('[;,|/]')) {
            String key = part.trim().toLowerCase();
            if (String.isNotBlank(key) && valuesByKey.containsKey(key)) {
                matched.add(valuesByKey.get(key));
            }
        }

        if (matched.size() == 1) {
            context.department = new List<String>(matched)[0];
            context.locked = true;
        } else if (matched.size() > 1) {
            context.note = 'Your profile lists several departments, so pick the right one for this ticket.';
        } else {
            context.note = 'Your department (' + context.rawDepartment
                + ') does not match a case department, so pick one.';
        }
        return context;
    }

    /** The running user's own record - name, contact details and department. */
    private static User runningUser() {
        List<User> users = [
            SELECT Id, Name, Phone, MobilePhone, Email, Department
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    // ------------------------------------------------------------------
    // Modules
    // ------------------------------------------------------------------

    /**
     * Every module in the matrix, with its L1 owner resolved so the form can show who
     * the ticket will land on before it is submitted.
     *
     * The module label comes from Module__c when that field exists, otherwise Name.
     * L1__c is handled whether it is a User lookup or a plain text name.
     */
    @AuraEnabled(cacheable=true)
    public static List<ModuleOption> getModules() {
        List<ModuleOption> options = new List<ModuleOption>();

        Schema.SObjectType matrixType = Schema.getGlobalDescribe().get(MATRIX_OBJECT);
        if (matrixType == null) {
            throw new AuraHandledException(MATRIX_OBJECT + ' does not exist in this org.');
        }
        Map<String, Schema.SObjectField> fieldMap = matrixType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(L1_FIELD.toLowerCase())) {
            throw new AuraHandledException(L1_FIELD + ' does not exist on ' + MATRIX_OBJECT + '.');
        }

        String labelField = fieldMap.containsKey('module__c') ? 'Module__c' : 'Name';
        Boolean l1IsLookup =
            fieldMap.get(L1_FIELD.toLowerCase()).getDescribe().getType() == Schema.DisplayType.REFERENCE;

        Set<String> selectFields = new Set<String>{ 'Id', 'Name', labelField, L1_FIELD };
        String soql = 'SELECT ' + String.join(new List<String>(selectFields), ', ')
            + ' FROM ' + MATRIX_OBJECT
            + ' ORDER BY ' + labelField + ' LIMIT 2000';

        // Dynamic SOQL takes its access level as an argument rather than a WITH clause.
        List<SObject> rows = Database.query(soql, AccessLevel.SYSTEM_MODE);

        // Resolve L1 to a real user, whichever way the field is modelled.
        Set<Id> userIds = new Set<Id>();
        Set<String> userNames = new Set<String>();
        for (SObject row : rows) {
            Object l1 = row.get(L1_FIELD);
            if (l1 == null) {
                continue;
            }
            if (l1IsLookup) {
                userIds.add((Id) l1);
            } else {
                userNames.add(String.valueOf(l1).trim());
            }
        }

        Map<Id, User> usersById = new Map<Id, User>();
        Map<String, User> usersByName = new Map<String, User>();
        if (!userIds.isEmpty()) {
            for (User u : [
                SELECT Id, Name, Email, IsActive FROM User WHERE Id IN :userIds WITH SYSTEM_MODE
            ]) {
                usersById.put(u.Id, u);
            }
        }
        if (!userNames.isEmpty()) {
            for (User u : [
                SELECT Id, Name, Email, IsActive
                FROM User
                WHERE IsActive = TRUE AND Name IN :userNames
                WITH SYSTEM_MODE
            ]) {
                usersByName.put(u.Name.toLowerCase(), u);
            }
        }

        for (SObject row : rows) {
            String moduleName = String.valueOf(row.get(labelField));
            if (String.isBlank(moduleName)) {
                continue;
            }
            ModuleOption option = new ModuleOption();
            option.value = String.valueOf(row.get('Id'));
            option.label = moduleName;

            User l1User = resolveUser(row.get(L1_FIELD), l1IsLookup, usersById, usersByName);
            if (l1User != null) {
                option.l1UserId   = l1User.Id;
                option.l1UserName = l1User.Name + (l1User.IsActive ? '' : ' (inactive)');
                option.l1Email    = l1User.Email;
            }
            options.add(option);
        }
        return options;
    }

    private static User resolveUser(Object l1Value, Boolean l1IsLookup,
                                    Map<Id, User> usersById, Map<String, User> usersByName) {
        if (l1Value == null) {
            return null;
        }
        if (l1IsLookup) {
            return usersById.get((Id) l1Value);
        }
        return usersByName.get(String.valueOf(l1Value).trim().toLowerCase());
    }

    // ------------------------------------------------------------------
    // Picklists
    // ------------------------------------------------------------------
    private static final List<String> FORM_PICKLISTS = new List<String>{
        'Department__c', 'Priority'
    };

    private static final String HEX_DIGITS = '0123456789ABCDEF';

    /**
     * Describe is used instead of the UI API because getPicklistValues filters by
     * record type: a field whose values are not assigned to the default record type
     * comes back empty with no error. Anything wrong lands in `diagnostic`.
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
    // Create
    // ------------------------------------------------------------------
    @AuraEnabled
    public static TicketResult createTicket(TicketRequest req) {
        if (req == null) {
            throw new AuraHandledException('No ticket details were received.');
        }
        if (String.isBlank(req.subject)) {
            throw new AuraHandledException('Enter a subject for the ticket.');
        }
        if (String.isBlank(req.moduleId)) {
            throw new AuraHandledException('Select the module this ticket belongs to.');
        }

        // Module and owner are re-read from the matrix - never taken from the browser.
        ModuleOption modules = findModule(req.moduleId);
        if (modules == null) {
            throw new AuraHandledException('That module could not be found in the ticket matrix.');
        }

        List<String> warnings = new List<String>();
        Id ownerId = UserInfo.getUserId();
        if (String.isNotBlank(modules.l1UserId)) {
            ownerId = (Id) modules.l1UserId;
        } else {
            warnings.add('No L1 user is set for ' + modules.label
                + ', so the ticket is assigned to you.');
        }

        // One read of the running user covers both the department lock and the
        // Phone_Number__c / Email__c stamp below.
        UserContext userContext = getUserContext();

        // When the form locked the field, the value is re-derived here rather than
        // trusted, so a locked control cannot be bypassed from the browser.
        String department = req.department;
        if (userContext.locked) {
            department = userContext.department;
        }

        Case ticket = new Case(
            RecordTypeId = internalTicketRecordTypeId(),
            Status       = DEFAULT_STATUS,
            Priority     = req.priority,
            Subject      = req.subject,
            Description  = req.description,
            OwnerId      = ownerId
        );

        List<String> skipped = new List<String>();
        putIfCreateable(ticket, 'Complaint_Category__c', modules.label, skipped);
        putIfCreateable(ticket, 'Department__c',         department,    skipped);

        // Who raised it, read from the User record rather than the browser so the
        // stamp cannot be forged and stays right even if the form is bypassed.
        if (userContext != null) {
            putIfCreateable(ticket, 'Phone_Number__c', userContext.userPhone, skipped);
            putIfCreateable(ticket, 'Email__c',        userContext.userEmail, skipped);
        }
        warnings.addAll(skipped);

        if (ticket.OwnerId == null) {
            ticket.OwnerId = UserInfo.getUserId();
        }

        try {
            insert ticket;
        } catch (DmlException e) {
            throw new AuraHandledException('The ticket could not be saved: ' + describeDml(e));
        }

        Case saved = [
            SELECT Id, CaseNumber, OwnerId, Owner.Name, Subject, Description, Priority
            FROM Case
            WHERE Id = :ticket.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        TicketResult result = new TicketResult();
        result.caseId     = saved.Id;
        result.caseNumber = saved.CaseNumber;
        result.ownerId    = saved.OwnerId;
        result.ownerName  = saved.Owner.Name;

        try {
            result.filesAttached = attachFiles(saved.Id, req.documentIds);
        } catch (Exception e) {
            result.filesAttached = 0;
            warnings.add('The ticket was raised but the files could not be attached. '
                + 'They are in your personal Files.');
        }

        sendPushNotification(saved, modules.label);
        result.emailSent = sendAssignmentEmail(saved, ownerId, modules.label, department);

        if (!warnings.isEmpty()) {
            result.warning = String.join(warnings, ' ');
        }
        return result;
    }

    /**
     * Record type id for internal tickets, looked up by developer name rather than
     * hard-coded - ids differ between sandbox and production.
     */
    @TestVisible
    private static Id internalTicketRecordTypeId() {
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
                + 'or it is inactive. Internal tickets cannot be raised without it.'
            );
        }
        return types[0].Id;
    }

    /** Re-reads one matrix row and resolves its L1 user. */
    private static ModuleOption findModule(Id moduleId) {
        for (ModuleOption option : getModules()) {
            if (option.value == String.valueOf(moduleId)) {
                return option;
            }
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Files
    // ------------------------------------------------------------------
    /**
     * Moves already-uploaded documents onto the ticket: adds the link, drops the
     * staging link against the uploader, and hands ownership to the ticket owner.
     * Apex only ever moves link rows, so file size is irrelevant here.
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
     * so the file lives on the ticket rather than in personal files as well.
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
            // The file is on the ticket either way; it just also stays in personal files.
            System.debug(LoggingLevel.WARN, 'Staging link cleanup failed: ' + e.getDmlMessage(0));
        }
    }

    /** Hands documents to the ticket owner when the uploader is somebody else. */
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

    /** Discards a staged file when the user removes it before raising the ticket. */
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
                System.debug(LoggingLevel.WARN, 'Ignoring invalid document id: ' + raw);
            }
        }
        return ids;
    }

    // ------------------------------------------------------------------
    // Notification + email
    // ------------------------------------------------------------------
    @TestVisible
    private static void sendPushNotification(Case c, String moduleName) {
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
            note.setTitle('New internal ticket: ' + c.CaseNumber);
            note.setBody(
                (String.isBlank(moduleName) ? '' : moduleName + '. ') +
                (String.isBlank(c.Subject) ? 'A ticket has been assigned to you.' : c.Subject)
            );
            note.send(new Set<String>{ String.valueOf(c.OwnerId) });
        } catch (Exception e) {
            // A failed notification must not roll back the ticket.
            System.debug(LoggingLevel.ERROR, 'Push notification failed: ' + e.getMessage());
        }
    }

    /**
     * Plain composed email rather than a template: the case templates in this org merge
     * against a Contact, and an internal ticket has none. Swap in setTemplateId with
     * setTargetObjectId(userId) if a user-targeted template is created later.
     */
    @TestVisible
    private static Boolean sendAssignmentEmail(Case c, Id assigneeId, String moduleName, String department) {
        try {
            List<User> assignees = [
                SELECT Id, Name, Email FROM User WHERE Id = :assigneeId WITH SYSTEM_MODE LIMIT 1
            ];
            if (assignees.isEmpty() || String.isBlank(assignees[0].Email)) {
                return false;
            }

            String recordUrl = URL.getOrgDomainUrl().toExternalForm()
                + '/lightning/r/Case/' + c.Id + '/view';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ assignees[0].Email });
            mail.setSubject('Internal ticket ' + c.CaseNumber + ': ' + c.Subject);
            mail.setHtmlBody(
                '<p>Hi ' + assignees[0].Name.escapeHtml4() + ',</p>'
                + '<p>An internal ticket has been assigned to you.</p>'
                + '<table cellpadding="4">'
                + row('Ticket', c.CaseNumber)
                + row('Module', moduleName)
                + row('Department', department)
                + row('Priority', c.Priority)
                + row('Subject', c.Subject)
                + '</table>'
                + (String.isBlank(c.Description)
                    ? ''
                    : '<p><b>Description</b><br/>' + c.Description.escapeHtml4() + '</p>')
                + '<p><a href="' + recordUrl + '">Open the ticket</a></p>'
            );
            mail.setSaveAsActivity(false);

            List<OrgWideEmailAddress> owea = [
                SELECT Id FROM OrgWideEmailAddress WHERE Address = :ORG_WIDE_EMAIL WITH SYSTEM_MODE LIMIT 1
            ];
            if (!owea.isEmpty()) {
                mail.setOrgWideEmailAddressId(owea[0].Id);
            }

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }, false);
            return true;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Assignment email failed: ' + e.getMessage());
            return false;
        }
    }

    private static String row(String label, String value) {
        if (String.isBlank(value)) {
            return '';
        }
        return '<tr><td><b>' + label.escapeHtml4() + '</b></td><td>' + value.escapeHtml4() + '</td></tr>';
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
            skipped.add(fieldApiName + ' does not exist on Case and was skipped.');
            return;
        }
        Schema.DescribeFieldResult dfr = token.getDescribe();
        if (!dfr.isCreateable()) {
            skipped.add(dfr.getLabel() + ' is read-only and was skipped.');
            return;
        }
        try {
            // sObject.put is strictly typed: a lookup needs an Id, not a String.
            if (dfr.getType() == Schema.DisplayType.REFERENCE && value instanceof String) {
                c.put(fieldApiName, Id.valueOf(((String) value).trim()));
            } else {
                c.put(fieldApiName, value);
            }
        } catch (Exception e) {
            skipped.add(dfr.getLabel() + ' could not be set: ' + e.getMessage());
        }
    }

    /** Status code and field names as well as the message - the message alone hides the cause. */
    private static String describeDml(DmlException e) {
        List<String> parts = new List<String>{ e.getDmlMessage(0) };
        if (e.getDmlStatusCode(0) != null) {
            parts.add('[' + e.getDmlStatusCode(0) + ']');
        }
        if (e.getDmlFieldNames(0) != null && !e.getDmlFieldNames(0).isEmpty()) {
            parts.add('fields: ' + String.join(e.getDmlFieldNames(0), ', '));
        }
        return String.join(parts, ' ');
    }
}