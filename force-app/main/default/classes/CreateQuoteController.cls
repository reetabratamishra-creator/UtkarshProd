/*
* Class Name  : QuoteTemplateController
* Author      : Reetabrata Mishra
* Date        : 06 March 2026
* Description : 
* This Apex controller is used to fetch active Quote Template configurations 
*/
public class CreateQuoteController {
    
    
    /*
* Method Name : getActiveTemplates
* Description :
* This method retrieves all active Quote Template records from the
* `Quote_Template_Config__mdt` custom metadata type where `Active__c = true`.
* 
* The method returns the MasterLabel (record display name) which is used
* as both the label and value for the LWC combobox options.
* Return Type :
* List<String> – List of active Quote Template names.
*/
    
    @AuraEnabled
    public static List<String> getActiveTemplates() {
        // 1. Get current user's departments
        User currentUser = [
            SELECT Departments__c 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ];
        
        // 2. If user has no departments, return empty list
        if (String.isBlank(currentUser.Departments__c)) {
            return new List<String>();
        }
        
        // 3. Convert multi-select picklist to Set
        Set<String> userDepartments = new Set<String>();
        for (String dept : currentUser.Departments__c.split(';')) {
            userDepartments.add(dept.trim());
        }
        
        // 4. Filter templates where DeveloperName matches user's departments
        List<String> templateNames = new List<String>();
        for (Quote_Template_Config__mdt rec : [
            SELECT MasterLabel, DeveloperName
            FROM Quote_Template_Config__mdt
            WHERE Active__c = true
            ORDER BY MasterLabel
        ]) {
            // 👉 THE FILTER: Only add if DeveloperName is in user's departments
            if (userDepartments.contains(rec.DeveloperName)) {
                templateNames.add(rec.MasterLabel);
            }
        }
        
        return templateNames;
    }
    
    /* Final_Quote_Amount__c is selected for the list's Amount column. GrandTotal
is the standard QuoteLineItem roll-up and these quotes carry no
QuoteLineItems, so it is always 0.00 - the real figure is captured into
Final_Quote_Amount__c on APPLY.
Approval_Due_Date__c feeds the Pending Approvals table, which shows the
approver the deadline they are working to rather than the date the quote
happened to be submitted. Deepanjan (12th August 2026) */
    
    @AuraEnabled
    public static List<Quote> getQuotesByOpportunity(Id opportunityId) {
        try {
            if(opportunityId == null){
                return new List<Quote>();
            }
            List<Quote> quotes = [
                SELECT Id, Name, QuoteNumber, Status, approved_by__r.Name, submition_date__c,CreatedBy.Name, GrandTotal,
                CreatedDate, CreatedById, LastModifiedDate, ExpirationDate, Description ,Quote_Value__c,Pending_Approver__c,
                Pending_Approver__r.Name, IsSyncing ,Finalized_Quote__c,Revision_No__c,
                Previous_Revision__c, Original_Quote__c,Approval_Submitted_By__c, Approval_Submitted_By__r.Name, 
                Rejection_Reason__c, Final_Quote_Amount__c ,Approval_Due_Date__c
                FROM Quote 
                WHERE OpportunityId = :opportunityId  AND Has_Quote_Value__c = true
                ORDER BY CreatedDate DESC
            ];
            return quotes;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading quotes: ' + e.getMessage());
        }
    }
    
    /* ═══════════ APPROVAL NOTIFICATIONS — Deepanjan (6th August 2026) ═══════════
One custom notification per approval event:
SUBMITTED -> the approver determineApprover() picked
APPROVED  -> back to Approval_Submitted_By__c
REJECTED  -> back to Approval_Submitted_By__c, with the reason inlined

Approval_Submitted_By__c, not CreatedById: a manager can submit a quote somebody
else built, and the answer has to reach whoever actually pressed Submit.

Delivery is best-effort by design. A missing notification type, a user
who has the type switched off, or any send failure must NEVER roll back
an approval, so the whole body sits in try/catch and returns quietly.
Requires the 'Quote_Approval_Alert' Custom Notification Type.          */
    @AuraEnabled
    public static String sendQuoteApprovalNotification(Id quoteId, Id recipientId, String kind) {
        if (quoteId == null || recipientId == null || String.isBlank(kind)) {
            return 'SKIPPED_MISSING_INPUT';
        }
        try {
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Quote_Approval_Alert'
                LIMIT 1
            ];
            if (types.isEmpty()) {
                System.debug('Custom Notification Type Quote_Approval_Alert not found - skipping.');
                return 'NO_NOTIFICATION_TYPE';
            }
            
            List<Quote> quotes = [
                SELECT Id, Name, QuoteNumber, Rejection_Reason__c, OpportunityId,
                       Opportunity.Name, Original_Quote_Number_After_Cloned__c   // CLONED kind - Deepanjan (7th September 2026)
                FROM Quote WHERE Id = :quoteId LIMIT 1
            ];
            if (quotes.isEmpty()) {
                return 'QUOTE_NOT_FOUND';
            }
            Quote q = quotes[0];
            String label = String.isBlank(q.QuoteNumber) ? q.Name : q.QuoteNumber;
            String actor = UserInfo.getName();
            
            String title;
            String body;
            if (kind == 'SUBMITTED') {
                title = 'Quote awaiting your approval';
                body  = actor + ' has sent quote ' + label + ' for your approval.';
            } else if (kind == 'APPROVED') {
                title = 'Quote approved';
                body  = 'Your quote ' + label + ' has been approved by ' + actor + '.';
            } else if (kind == 'REJECTED') {
                title = 'Quote rejected';
                body  = 'Your quote ' + label + ' has been rejected by ' + actor + '.';
                if (String.isNotBlank(q.Rejection_Reason__c)) {
                    body += ' Reason: ' + q.Rejection_Reason__c;
                }
            } else if (kind == 'CLONED') {
                // QUOTE CLONE - Deepanjan (7th September 2026). Sent to the user who
                // pressed Create; quoteId here is the NEW quote, so the landing record
                // (below) is the opportunity it was cloned INTO.
                title = 'Quote cloned';
                body  = 'Quote ' + label + ' has been created by cloning '
                      + (String.isBlank(q.Original_Quote_Number_After_Cloned__c) ? 'a finalized quote' : q.Original_Quote_Number_After_Cloned__c)
                      + (q.Opportunity != null && String.isNotBlank(q.Opportunity.Name) ? ' on opportunity ' + q.Opportunity.Name : '')
                      + '.';
            } else {
                return 'UNKNOWN_KIND_' + kind;
            }
            
            // Platform caps: title 250, body 750. Trim rather than let send() throw.
            if (title.length() > 250) { title = title.substring(0, 247) + '...'; }
            if (body.length()  > 750) { body  = body.substring(0, 747)  + '...'; }
            
            /* Clicking the notification opens this record. It points at the
OPPORTUNITY, not the Quote: the createQuote LWC - and with it the
Pending Approvals tab and the Approve/Reject buttons - lives on the
Opportunity record page, so the Quote page would drop the approver
somewhere they cannot act. Falls back to the Quote if the Quote
somehow has no Opportunity. Swap the two lines to reverse this. */
            Id landingId = (q.OpportunityId != null) ? (Id) q.OpportunityId : quoteId;
            
            Messaging.CustomNotification note = new Messaging.CustomNotification();
            note.setNotificationTypeId(types[0].Id);
            note.setTargetId(landingId);
            note.setTitle(title);
            note.setBody(body);
            note.send(new Set<String>{ String.valueOf(recipientId) });
            return 'SENT' +body;
            
        } catch (Exception e) {
            System.debug('sendQuoteApprovalNotification failed: ' + e.getMessage());
            return 'FAILED: ' + e.getMessage();
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // QUOTE REVISION - Deepanjan (20th July 2026)
    // Called ONLY by the RE-OPEN FOR EDIT button when the quote is
    // Approved/Rejected. Clones the quote into a NEW Draft record and chains
    // the two via the lookups created in Setup:
    //   Previous_Revision__c -> the quote it was created from
    //   Original_Quote__c    -> the family root (R0)
    // The old record is never modified; nothing else in this class changed.
    // Linear chain: a quote that already has a revision cannot be revised
    // again. New ExpirationDate counts fresh from today with the parent's
    // created->expiry duration (min 1 day).
    // ═══════════════════════════════════════════════════════════════════════
    @AuraEnabled
    public static Id createRevision(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        
        Integer children = [SELECT COUNT() FROM Quote WHERE Previous_Revision__c = :quoteId];
        if (children > 0) {
            throw new AuraHandledException('This quote already has a newer revision. Open the latest revision to make changes.');
        }
        
        List<Quote> srcList = [
            SELECT Id, Name, OpportunityId, Status, Description, Quote_Value__c,
            ExpirationDate, CreatedDate, Revision_No__c, Original_Quote__c,
            Pricebook2Id
            FROM Quote WHERE Id = :quoteId LIMIT 1
        ];
        if (srcList.isEmpty()) {
            throw new AuraHandledException('Quote not found.');
        }
        Quote src = srcList[0];
        
        Date newExpiry = null;
        if (src.ExpirationDate != null && src.CreatedDate != null) {
            Integer durationDays = src.CreatedDate.date().daysBetween(src.ExpirationDate);
            if (durationDays < 1) durationDays = 1;
            newExpiry = Date.today().addDays(durationDays);
        } else {
            // Parent had no expiry (blank "—"): give the revision a default
            // 30-day window from today rather than leaving it blank too.
            // Deepanjan (20th July 2026)
            newExpiry = Date.today().addDays(30);
        }
        
        Quote rev = new Quote(
            Name                 = src.Name,
            OpportunityId        = src.OpportunityId,
            Status               = 'Draft',
            Description          = src.Description,
            Quote_Value__c       = src.Quote_Value__c,
            Has_Quote_Value__c   = String.isNotBlank(src.Quote_Value__c),
            Pricebook2Id         = src.Pricebook2Id,
            // ExpirationDate restored - Deepanjan (20th July 2026): fresh validity
            // counted from today (parent's duration, or 30-day default above).
            ExpirationDate       = newExpiry,
            Revision_No__c       = (src.Revision_No__c == null ? 0 : src.Revision_No__c) + 1,
            Previous_Revision__c = src.Id,
            Original_Quote__c    = (src.Original_Quote__c == null ? src.Id : src.Original_Quote__c)
        );
        insert rev;
        
        // Stamp the revision's own reference (UIL/Dept/FY/NewQuoteNo/Rn). The
        // department is read from the copied Quote_Value__c JSON's saved template
        // name, so it matches what the LWC would pass. Best-effort: a reference
        // failure must not block the revision. Deepanjan (21st July 2026)
        try {
            String dept = null;
            if (String.isNotBlank(rev.Quote_Value__c)) {
                Map<String,Object> jd = (Map<String,Object>) JSON.deserializeUntyped(rev.Quote_Value__c);
                Object t = jd.get('_Saved_Template_Name');
                if (t != null) dept = String.valueOf(t);
            }
            generateQuoteReference(rev.Id, dept);
        } catch (Exception ignored) { /* reference is non-blocking */ }
        
        return rev.Id;
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // QUOTE CLONE - Deepanjan (7th September 2026)
    // "Clone this Quote" is offered on a FINALIZED quote (IsSyncing = true). The
    // user picks a target opportunity (default: the current one) and Create copies
    // every createable, non-formula Quote field into a NEW Draft quote on that
    // opportunity, stamps Cloned__c / Original_Quote_Number_After_Cloned__c, and
    // notifies the user who pressed Create. These quotes carry no QuoteLineItems
    // (everything lives in Quote_Value__c), so the record copy is the whole copy.
    //
    // Field selection is by DESCRIBE, not a hand list, so a field added to Quote
    // later is cloned without touching this code. Formula (isCalculated) and
    // auto-number fields are skipped by the describe; the workflow fields in
    // CLONE_RESET are deliberately NOT carried across - the clone starts its own
    // life as a fresh Draft.
    // ═══════════════════════════════════════════════════════════════════════
    public class CloneOppOption {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String stageName;
        @AuraEnabled public String accountName;
        @AuraEnabled public Boolean isClosed;
        @AuraEnabled public Boolean isOwner;
    }

    public class CloneResult {
        @AuraEnabled public String newQuoteId;
        @AuraEnabled public String newQuoteNumber;
        @AuraEnabled public String opportunityId;
        @AuraEnabled public Boolean sameOpportunity;
    }

    // Fields that exist on the source but must NOT be copied onto the clone.
    // Approval / revision / sync state, the two clone stamps (set explicitly),
    // and the two lookups the clone sets itself.
    private static final Set<String> CLONE_RESET = new Set<String>{
        'opportunityid', 'pricebook2id', 'status',
        'pending_approver__c', 'approval_submitted_by__c', 'approved_by__c',
        'submition_date__c', 'rejection_reason__c', 'approval_due_date__c',
        'previous_revision__c', 'original_quote__c', 'revision_no__c',
        'quote_reference__c',
        'cloned__c', 'original_quote_number_after_cloned__c',
        'expirationdate'
    };

    // Default entry for the modal: the opportunity the quote is on, whatever its
    // stage or owner - the user may keep it or search for another.
    @AuraEnabled(cacheable=true)
    public static CloneOppOption getOpportunityForClone(Id opportunityId) {
        if (opportunityId == null) return null;
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, IsClosed, OwnerId, Account.Name
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty()) return null;
        return toCloneOption(opps[0]);
    }

    // Search for the modal: by name, only the running user's own OPEN
    // opportunities (IsClosed = false covers both Closed Won and Closed Lost).
    @AuraEnabled(cacheable=true)
    public static List<CloneOppOption> searchOpportunitiesForClone(String searchTerm) {
        String term = String.isBlank(searchTerm) ? '' : searchTerm.trim();
        String likeTerm = '%' + String.escapeSingleQuotes(term) + '%';
        Id me = UserInfo.getUserId();
        List<CloneOppOption> out = new List<CloneOppOption>();
        for (Opportunity o : [
            SELECT Id, Name, StageName, IsClosed, OwnerId, Account.Name
            FROM Opportunity
            WHERE OwnerId = :me
              AND IsClosed = false
              AND Name LIKE :likeTerm
            ORDER BY LastModifiedDate DESC
            LIMIT 50
        ]) {
            out.add(toCloneOption(o));
        }
        return out;
    }

    private static CloneOppOption toCloneOption(Opportunity o) {
        CloneOppOption c = new CloneOppOption();
        c.id          = o.Id;
        c.name        = o.Name;
        c.stageName   = o.StageName;
        c.accountName = (o.Account != null) ? o.Account.Name : '';
        c.isClosed    = o.IsClosed;
        c.isOwner     = (o.OwnerId == UserInfo.getUserId());
        return c;
    }

    @AuraEnabled
    public static CloneResult cloneQuote(Id quoteId, Id targetOpportunityId) {
        if (quoteId == null)             throw new AuraHandledException('Quote Id is required.');
        if (targetOpportunityId == null) throw new AuraHandledException('Please select an opportunity to clone into.');

        List<Opportunity> targets = [
            SELECT Id, Name, Pricebook2Id, IsClosed, OwnerId
            FROM Opportunity WHERE Id = :targetOpportunityId LIMIT 1
        ];
        if (targets.isEmpty()) throw new AuraHandledException('The selected opportunity could not be found.');
        Opportunity target = targets[0];

        // ── 1. Which fields travel: createable, not formula, not auto-number ──
        Map<String, Schema.SObjectField> fmap = Schema.SObjectType.Quote.fields.getMap();
        List<String> copyFields = new List<String>();
        for (String fname : fmap.keySet()) {
            Schema.DescribeFieldResult dfr = fmap.get(fname).getDescribe();
            if (!dfr.isCreateable())            continue;   // system / read-only / no FLS
            if (dfr.isCalculated())             continue;   // formula - recomputes itself
            if (dfr.isAutoNumber())             continue;
            if (CLONE_RESET.contains(fname))    continue;   // handled explicitly below
            copyFields.add(fname);
        }
        if (copyFields.isEmpty()) throw new AuraHandledException('No cloneable fields found on Quote.');

        String soql = 'SELECT ' + String.join(copyFields, ', ')
                    + ', QuoteNumber, IsSyncing, Status, ExpirationDate, CreatedDate, OpportunityId'   // OpportunityId sits in CLONE_RESET (not copied) but sameOpportunity needs it; Quote_Value__c is already in copyFields - listing a field twice is a SOQL error
                    + ' FROM Quote WHERE Id = :quoteId LIMIT 1';
        List<Quote> srcList = Database.query(soql);
        if (srcList.isEmpty()) throw new AuraHandledException('Quote not found.');
        Quote src = srcList[0];

        if (src.IsSyncing != true && src.Status != 'Approved') {
            throw new AuraHandledException('Only an approved or finalized quote can be cloned.');
        }

        // ── 2. Build the clone field by field (never clone() - that would carry
        //       the read-only columns we queried for our own use) ──
        Quote c = new Quote();
        for (String fname : copyFields) {
            Object v = src.get(fname);
            if (v != null) c.put(fname, v);
        }
        c.OpportunityId = target.Id;
        // A quote's price book must match its opportunity's; a null on the
        // opportunity simply lets the quote inherit.
        c.Pricebook2Id  = target.Pricebook2Id;
        c.Status        = 'Draft';
        c.Cloned__c     = true;
        c.Original_Quote_Number_After_Cloned__c = src.QuoteNumber;
        // Revision chain starts fresh - the clone is R0 of its own family.
        c.Revision_No__c = 0;

        // Validity counted from today with the source's created->expiry duration
        // (min 1 day), 30 days if the source had none - same rule as createRevision.
        Integer durationDays = 30;
        if (src.ExpirationDate != null && src.CreatedDate != null) {
            durationDays = src.CreatedDate.date().daysBetween(src.ExpirationDate);
            if (durationDays < 1) durationDays = 1;
        }
        c.ExpirationDate = Date.today().addDays(durationDays);

        insert c;

        // ── 3. Reference for the new number - best-effort, like createRevision ──
        try {
            String dept = null;
            String qv = copyFields.contains('quote_value__c') ? (String) src.get('Quote_Value__c') : null;
            if (String.isNotBlank(qv)) {
                Map<String,Object> jd = (Map<String,Object>) JSON.deserializeUntyped(qv);
                Object t = jd.get('_Saved_Template_Name');
                if (t != null) dept = String.valueOf(t);
            }
            generateQuoteReference(c.Id, dept);
        } catch (Exception ignored) { /* reference is non-blocking */ }

        // ── 4. Tell the user who pressed Create. Best-effort (the helper never throws). ──
        sendQuoteApprovalNotification(c.Id, UserInfo.getUserId(), 'CLONED');

        CloneResult r = new CloneResult();
        r.newQuoteId       = c.Id;
        r.opportunityId    = target.Id;
        r.sameOpportunity  = (target.Id == src.OpportunityId);
        List<Quote> back   = [SELECT QuoteNumber FROM Quote WHERE Id = :c.Id LIMIT 1];
        r.newQuoteNumber   = back.isEmpty() ? '' : back[0].QuoteNumber;
        return r;
    }

    // ==========================================
    // NEW METADATA ENGINE (With Section Visibility)
    // ==========================================
    public class ConfigWrapper {
        @AuraEnabled public List<Accordion_Section__mdt> sections;
        @AuraEnabled public List<Section_Logic__mdt> logicRules;
        @AuraEnabled public Boolean isApprovalActive; // 👉 NEW FIELD
        @AuraEnabled public Boolean canCreate;
		@AuraEnabled public String  denialMessage;
    }
    
    private static final String CREATE_QUOTE_PERMISSION = 'Can_Create_Quote';
	private static final String CREATE_QUOTE_DENIAL_MSG =
    'You do not have permission to create a quotation. '
  + 'Please contact your system administrator to get access.';
    
    @AuraEnabled
    public static ConfigWrapper getDynamicConfiguration(String templateName) {
        ConfigWrapper wrapper = new ConfigWrapper();
        
        wrapper.canCreate = FeatureManagement.checkPermission(CREATE_QUOTE_PERMISSION);
        if (wrapper.canCreate != true) {
            wrapper.denialMessage = CREATE_QUOTE_DENIAL_MSG;
            return wrapper;
        }
        
        if(String.isBlank(templateName)) {
            return wrapper;
        }
        
        // 👉 1. Fetch the Approval Active flag from the Template Metadata
        List<Quote_Template_Config__mdt> templateConfigs = [
            SELECT approval_active__c 
            FROM Quote_Template_Config__mdt 
            WHERE MasterLabel = :templateName 
            LIMIT 1
        ];
        
        // Safely set the boolean (defaults to false if null or not found)
        wrapper.isApprovalActive = !templateConfigs.isEmpty() && templateConfigs[0].approval_active__c == true;
        
        // 2. Fetch Accordions, their Root Fields, AND Section Visibility Rules
        wrapper.sections = [
            SELECT Id, MasterLabel, Sequence_No__c,
            First_Field_Label__c, First_Field_API_Name__c, First_Field_Options__c,
            Controlling_Field__c, Controlling_Value__c , First_Field_Required__c 
            FROM Accordion_Section__mdt
            WHERE Template__r.MasterLabel = :templateName 
            AND Active__c = true
            ORDER BY Sequence_No__c ASC
        ];
        
        // 3. Fetch all JSON payloads associated with those Accordions
        wrapper.logicRules = [
            SELECT Accordion_Section__c, Controlling_Value__c, JSON_Payload__c, Blueprint_Library__c 
            FROM Section_Logic__mdt
            WHERE Accordion_Section__r.Template__r.MasterLabel = :templateName
            AND Active__c = true
        ];
        
        return wrapper;
    }
    
    // 👉 NEW METHOD: The Modal calls this ONLY when it opens
    @AuraEnabled(cacheable=true)
    public static String fetchBlueprintPayload(Id blueprintId) {
        if (blueprintId == null) return null;
        
        Blueprint_Library__mdt lib = [
            SELECT JSON_Payload__c 
            FROM Blueprint_Library__mdt 
            WHERE Id = :blueprintId 
            LIMIT 1
        ];
        
        return lib.JSON_Payload__c;
    }
    
    /* CUSTOMER ADDRESS - resolved from Address_Book__c instead of the Account address
fields. Deepanjan (12th August 2026)

This replaces the two old Account based methods that used to sit here - one that
read the Account address and one that wrote the override back on to the Account.
The read method's name is kept, so createQuote.js needs no change at the call
site. The return type is now a Map instead of an Account: createQuote.js only
walks the keys of this result, and a Map lets us decide exactly which keys exist.

Contract with createQuote.js: it replaces every @@key@@ merge tag in the modal
config with the matching value from this map, then turns any tag it could not
match into 'Not Found'. So a key left out of this map renders as 'Not Found' -
that is how a blank field is expressed here.

Rules:
- Address books on the Opportunity win outright. If the Opportunity has even
one, the Account is never consulted for the address.
- Only when the Opportunity has none do we fall back to the address books
hanging off the Account.
- Among several records: Primary_Address__c first, then the record with the
most fields filled in, then the oldest.
- The winning record is used whole. A blank field on it stays blank; values are
never mixed in from another record or from the Account.
- Phone, Email and Website are unchanged - they still come from the Account.
- Billing and Shipping are not distinguished. The one address feeds both
families of tags. */
    @AuraEnabled
    public static Map<String, String> getOpportunityAccountAddress(Id opportunityId) {
        Map<String, String> ctx = new Map<String, String>();
        if (opportunityId == null) return ctx;
        
        List<Opportunity> opps = [
            SELECT AccountId, Account.Phone, Account.Email__c, Account.Website
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) return ctx;
        
        if (opps[0].Account != null) {
            putIfFilled(ctx, 'Phone',    opps[0].Account.Phone);
            putIfFilled(ctx, 'Email__c', opps[0].Account.Email__c);
            putIfFilled(ctx, 'Website',  opps[0].Account.Website);
        }
        
        List<Address_Book__c> books = [
            SELECT Id, Street__c, City__c, State__c, PIN__c, Country__c, Primary_Address__c
            FROM Address_Book__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate ASC
        ];
        
        if (books.isEmpty() && opps[0].AccountId != null) {
            books = [
                SELECT Id, Street__c, City__c, State__c, PIN__c, Country__c, Primary_Address__c
                FROM Address_Book__c
                WHERE Account__c = :opps[0].AccountId
                ORDER BY CreatedDate ASC
            ];
        }
        
        Address_Book__c book = pickAddressBook(books);
        if (book == null) return ctx;
        
        // The Id of the record actually used. createQuote.js hands it straight back if
        // the override write-back is ever switched on, so nothing has to look the record
        // up a second time. No payload has an @@AddressBookId@@ tag, so this key is
        // invisible to the merge. Deepanjan (12th August 2026)
        ctx.put('AddressBookId', book.Id);
        
        putIfFilled(ctx, 'ShippingStreet',     book.Street__c);
        putIfFilled(ctx, 'BillingStreet',      book.Street__c);
        putIfFilled(ctx, 'ShippingCity',       book.City__c);
        putIfFilled(ctx, 'BillingCity',        book.City__c);
        putIfFilled(ctx, 'ShippingState',      book.State__c);
        putIfFilled(ctx, 'BillingState',       book.State__c);
        putIfFilled(ctx, 'ShippingPostalCode', book.PIN__c);
        putIfFilled(ctx, 'BillingPostalCode',  book.PIN__c);
        putIfFilled(ctx, 'ShippingCountry',    book.Country__c);
        putIfFilled(ctx, 'BillingCountry',     book.Country__c);
        
        return ctx;
    }
    
    /* A blank value never enters the map, so its tag falls through to the 'Not Found'
catch-all in createQuote.js. Deepanjan (12th August 2026) */
    private static void putIfFilled(Map<String, String> ctx, String key, String value) {
        if (String.isNotBlank(value)) {
            ctx.put(key, sanitizeForTag(value));
        }
    }
    
    /* The merge tag being replaced sits inside a JSON string in the modal config, and
createQuote.js parses that config right after the replacement. So a raw value can
break the parse and the modal then refuses to open. Street__c is a text area, so a
customer address with a line break in it is not an edge case, it is normal typing.

Three things are neutralised here:
- backslash and double quote are escaped, so the JSON stays valid and parses
back to the very characters the user typed
- carriage return, line feed and tab become ', ' / ' ', because the modal field
is a single line input and a control character is illegal inside JSON anyway
- a lone $ is doubled, because String.replace() in JavaScript treats $&, $` and
$' inside the replacement as patterns. Doubling makes it emit a literal $.

Deepanjan (12th August 2026) */
    @TestVisible
    private static String sanitizeForTag(String value) {
        if (String.isBlank(value)) return '';
        
        String out = value.replace('\\', '\\\\')     // must run before the quote escape
            .replace('"',  '\\"');
        
        out = out.replaceAll('\\r\\n|\\r|\\n', ', ') // line breaks -> comma separated
            .replace('\t', ' ')
            .replace('$', '$$');                // literal $ for String.replace()
        
        // collapse the runs of blanks a flattened address leaves behind
        out = out.replaceAll(' {2,}', ' ').replaceAll('(, ){2,}', ', ').trim();
        if (out.endsWith(',')) out = out.removeEnd(',');
        return out;
    }
    
    /* Primary first, then the fullest record, then the oldest. The list arrives ordered
by CreatedDate ascending and the comparison below is strict, so the earliest
record keeps a tie. Deepanjan (12th August 2026) */
    @TestVisible
    private static Address_Book__c pickAddressBook(List<Address_Book__c> books) {
        Address_Book__c best = null;
        Integer bestFilled   = -1;
        Boolean bestPrimary  = false;
        
        for (Address_Book__c b : books) {
            Boolean isPrimary = (b.Primary_Address__c == true);
            Integer filled    = filledCount(b);
            
            Boolean wins = (best == null)
                || (isPrimary && !bestPrimary)
                || (isPrimary == bestPrimary && filled > bestFilled);
            
            if (wins) {
                best        = b;
                bestFilled  = filled;
                bestPrimary = isPrimary;
            }
        }
        return best;
    }
    
    /* How many of the five address fields carry a value. Deepanjan (12th August 2026) */
    @TestVisible
    private static Integer filledCount(Address_Book__c b) {
        Integer n = 0;
        if (String.isNotBlank(b.Street__c))  n++;
        if (String.isNotBlank(b.City__c))    n++;
        if (String.isNotBlank(b.State__c))   n++;
        if (String.isNotBlank(b.PIN__c))     n++;
        if (String.isNotBlank(b.Country__c)) n++;
        return n;
    }
    
    
    
    // 1. Fetches the Weight_Calculator__c record based on the Dropdown (e.g., "Transmission Pole")
    @AuraEnabled(cacheable=true)
    public static Price_Calculator__mdt getPricingRates(String departmentName) {
        try {
            Price_Calculator__mdt calc = [
                SELECT Id, Department__c, Base_Amount__c, Add_On_Amount__c,
                tp_segment__c, fm_general_detail__c, man_riding_lift__c,
                GST__c, rateCard__c, JSON_Payload__c
                FROM Price_Calculator__mdt
                WHERE Department__c = :departmentName
                LIMIT 1
            ];
            
            Decimal base  = (calc.Base_Amount__c  != null) ? calc.Base_Amount__c  : 0;
            Decimal addOn = (calc.Add_On_Amount__c != null) ? calc.Add_On_Amount__c : 0;
            calc.Base_Amount__c = base + addOn;   // in-memory override; caller sees the effective base
            
            return calc;
        } catch (Exception e) {
            return new Price_Calculator__mdt(); // Return empty if not found so UI doesn't crash
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getRateCardJson(String departmentName) {
        try {
            Price_Calculator__mdt calc = [
                SELECT JSON_Payload__c, rateCard__c FROM Price_Calculator__mdt WHERE Department__c = :departmentName LIMIT 1];
            return String.isNotBlank(calc.JSON_Payload__c) ? calc.JSON_Payload__c : calc.rateCard__c;
        } catch (Exception e) {
            return null;
        }
    }
    
    // 2. Inserts the Lines
    @AuraEnabled
    public static void generateQuoteLines(Id quoteId, List<Map<String, Object>> parsedLineItems) {
        
        
        // Replace (not append) this quote's line items: remove the existing set before
        // inserting the fresh one, so reopening a quote, editing, and re-applying does not
        // duplicate line items in Salesforce. Delete + insert run in the same transaction,
        // so a failed insert rolls the delete back too. Reetabrata (14th July 2026)
        
        if (quoteId != null) {
            List<Quote_Line_Item__c> existingLines = [SELECT Id FROM Quote_Line_Item__c WHERE Quote__c = :quoteId];
            if (!existingLines.isEmpty()) {
                delete existingLines;
            }
        }
        
        List<Quote_Line_Item__c > linesToInsert = new List<Quote_Line_Item__c >();
        for (Map<String, Object> item : parsedLineItems) {
            Quote_Line_Item__c  qli = new Quote_Line_Item__c ();
            qli.Quote__c  = quoteId;
            qli.Name = (String) item.get('name');
            qli.Quantity__c  = (Decimal) item.get('quantity');
            qli.UNIT_PRICE__c  = (Decimal) item.get('unitPrice');
            qli.UNIT_COST__c  = (Decimal) item.get('unitCost');
            qli.Weight__c  = (Decimal) item.get('weight');
            qli.EXPENSES__c = (Decimal) item.get('expenses');
            qli.UNIT_LIST_PRICE__c = (Decimal) item.get('unitListPrice');
            qli.Discount_Percentage__c = (Decimal) item.get('discount');
            if (item.containsKey('margin')) {
                qli.MARGIN__c = (Decimal) item.get('margin');
            }
            linesToInsert.add(qli);
        }
        if (!linesToInsert.isEmpty()) insert linesToInsert;
    }
    
    @AuraEnabled
    public static List<Quote_Line_Item__c> getCustomQuoteLines(Id quoteId) {
        return [
            SELECT Id, Name, Quantity__c, UOM__c, Weight__c, UNIT_COST__c, UNIT_PRICE__c, 
            EXPENSES__c, Discount_Percentage__c, NET_PRICE__c, MARGIN__c, COST__c ,UNIT_LIST_PRICE__c
            FROM Quote_Line_Item__c 
            WHERE Quote__c = :quoteId 
            ORDER BY CreatedDate ASC
        ];
    }
    
    @AuraEnabled
    public static List<Document_Template_Mapping__mdt> getAvailableMappings(String department) {
        if (String.isBlank(department)) {
            return new List<Document_Template_Mapping__mdt>();
        }
        // 👉 Returns ALL templates for the specific department
        return [
            SELECT Template_Type__c, PDF_VF_Page__c, Excel_VF_Page__c, Word_VF_Page__c 
            FROM Document_Template_Mapping__mdt
            WHERE Department__c = :department 
            ORDER BY Template_Type__c ASC
        ];
    }
    
    // ==========================================
    // PRICE VARIATION DATA FETCH
    // ==========================================
    public class PriceVariationData {
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal billetsPrice;
        @AuraEnabled public Decimal zincPrice;
        @AuraEnabled public Decimal cpiValue;
        @AuraEnabled public String  zincCoatingType;
        @AuraEnabled public Boolean calOnPercentage;
        @AuraEnabled public Decimal addOnAmount;
        @AuraEnabled public Decimal addOnPercentage;
    }
    
    @AuraEnabled(cacheable=false)
    public static PriceVariationData getPriceVariationData(String month, String year, String materialType, String priceBasisType) {
        PriceVariationData result = new PriceVariationData();
        result.unitPrice       = 0;
        result.billetsPrice    = 0;
        result.zincPrice       = 0;
        result.cpiValue        = 0;
        result.zincCoatingType = '';
        result.calOnPercentage = false;
        result.addOnAmount     = 0;
        result.addOnPercentage = 0;
        
        String basisType = String.isNotBlank(priceBasisType) ? priceBasisType : 'Price Variation';
        
        if (String.isNotBlank(materialType)) {
            List<Core_Unit_Price__mdt> unitPriceRecs = [
                SELECT Unit_Price__c, Zinc_Coating_Type__c,
                Cal_on_Percentage__c, Add_on_Amount__c, Add_on_Percentage__c
                FROM Core_Unit_Price__mdt
                WHERE Price_Basis_Type__c = :basisType
                AND   Material_List_Type__c = :materialType
                LIMIT 1
            ];
            if (!unitPriceRecs.isEmpty()) {
                Core_Unit_Price__mdt rec = unitPriceRecs[0];
                result.unitPrice       = rec.Unit_Price__c        != null ? rec.Unit_Price__c        : 0;
                result.zincCoatingType = rec.Zinc_Coating_Type__c != null ? rec.Zinc_Coating_Type__c : '';
                result.calOnPercentage = rec.Cal_on_Percentage__c == true;
                result.addOnAmount     = rec.Add_on_Amount__c     != null ? rec.Add_on_Amount__c     : 0;
                result.addOnPercentage = rec.Add_on_Percentage__c != null ? rec.Add_on_Percentage__c : 0;
            }
        }
        
        if (String.isNotBlank(month) && String.isNotBlank(year)) {
            List<Core_Pricing__mdt> pricingRecs = [
                SELECT Material__c, Unit_Price__c
                FROM Core_Pricing__mdt
                WHERE Month__c    = :month
                AND   Year__c     = :year
                AND   Material__c IN ('Billets', 'Zinc', 'CPI')
            ];
            for (Core_Pricing__mdt rec : pricingRecs) {
                if (rec.Unit_Price__c == null) continue;
                if      (rec.Material__c == 'Billets') result.billetsPrice = rec.Unit_Price__c;
                else if (rec.Material__c == 'Zinc')    result.zincPrice    = rec.Unit_Price__c;
                else if (rec.Material__c == 'CPI')     result.cpiValue     = rec.Unit_Price__c;
            }
        }
        
        return result;
    }
    
    public class TranmissionPricingData{
        @AuraEnabled public Decimal billetsPrice;
        @AuraEnabled public Decimal bloomsPrice;
        @AuraEnabled public Decimal zincPrice;
        @AuraEnabled public Decimal cpiValue;
    }
    
    @AuraEnabled(cacheable=false)
    public static TranmissionPricingData getTransmissionPricing(String month, String year){
        TranmissionPricingData result = new TranmissionPricingData();
        List<Transmission_Pricing__mdt > prices = [
            SELECT Material__c, Unit_Price__c
            FROM Transmission_Pricing__mdt 
            WHERE Month__c = :month
            AND Year__c = :year
            AND Pricing_Type__c  = 'Price Variation'
            AND Material__c IN ('Billets','Blooms','Zinc','CPI')
        ];
        
        Map<String, Decimal> priceMap = new Map<String, Decimal>();
        for(Transmission_Pricing__mdt p : prices){
            priceMap.put(p.Material__c, p.Unit_Price__c);
        }
        
        result.billetsPrice = priceMap.get('Billets');
        result.bloomsPrice = priceMap.get('Blooms');
        result.zincPrice = priceMap.get('Zinc');
        result.cpiValue = priceMap.get('CPI');
        
        System.debug('****line 346' + result);
        return result;
    }
    
    /*
@AuraEnabled(cacheable=true)
public static List<Steel_Pipe_Matrix__mdt> getSteelPipeMatrix() {
return [SELECT MasterLabel, DeveloperName, Standard__c, Shape__c, Pipe_Class__c, Size_NB__c, Weight_Per_Meter__c FROM Steel_Pipe_Matrix__mdt];
}*/
    
    @AuraEnabled
    public static String determineApprover(String department, String itemsJson) {
        System.debug('--- STARTING LINE-ITEM APPROVAL ROUTING ---');
        
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        Object deserialized = JSON.deserializeUntyped(itemsJson);
        
        // 👉 TRAP 1 FIXED & ROOT SCANNER ADDED: Safely extract both root fields and line items
        if (deserialized instanceof List<Object>) {
            // Handle simple list payload
            List<Object> rawItems = (List<Object>) deserialized;
            for(Object obj : rawItems) {
                Map<String, Object> rawMap = (Map<String, Object>) obj;
                Map<String, Object> lowerCaseMap = new Map<String, Object>();
                for(String key : rawMap.keySet()) {
                    lowerCaseMap.put(key.toLowerCase(), rawMap.get(key));
                }
                items.add(lowerCaseMap);
            }
        } else if (deserialized instanceof Map<String, Object>) {
            // Handle complex object payload
            Map<String, Object> payloadMap = (Map<String, Object>) deserialized;
            
            // Add the root flat fields to the evaluation pool
            Map<String, Object> lowerRoot = new Map<String, Object>();
            for(String key : payloadMap.keySet()) {
                lowerRoot.put(key.toLowerCase(), payloadMap.get(key));
            }
            // Give the root a name so product-specific rules still apply
            Object dynamicName = payloadMap.get('_Dynamic_Product_Name');
            lowerRoot.put('name', dynamicName != null ? dynamicName : 'ALL'); 
            items.add(lowerRoot); 
            
            // 👉 STALE DATA FIX: Prioritize fresh LWC UI rows over stale DB lines
            List<Object> rawItems = new List<Object>();
            if (payloadMap.containsKey('_Final_Apex_Lines')) {
                rawItems = (List<Object>) payloadMap.get('_Final_Apex_Lines');
            } else if (payloadMap.containsKey('_Saved_Table_Rows')) {
                rawItems = (List<Object>) payloadMap.get('_Saved_Table_Rows');
            }
            
            // Add the child line items to the evaluation pool
            if (rawItems != null) {
                for(Object obj : rawItems) {
                    Map<String, Object> rawMap = (Map<String, Object>) obj;
                    Map<String, Object> lowerCaseMap = new Map<String, Object>();
                    for(String key : rawMap.keySet()) {
                        lowerCaseMap.put(key.toLowerCase(), rawMap.get(key));
                    }
                    items.add(lowerCaseMap);
                }
            }
        }
        
        // 👉 GET USER ROLE
        User currentUser = [SELECT UserRole.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String rawRoleName = currentUser.UserRole != null ? currentUser.UserRole.Name : 'No_Role';
        List<String> validLevels = new List<String>{ rawRoleName, 'ALL' };
            
            // 👉 QUERY UPDATE: Now fetching Category__c and Sub_Component__c
            List<Quote_Approval_Matrix__mdt> rules = [
                SELECT Approver__c, Min_value__c, Max_value__c, Product__c, Evaluation_Metric__c, 
                Escalation__c, Category__c, Sub_Component__c
                FROM Quote_Approval_Matrix__mdt
                WHERE Department__c = :department
                AND Submitterlevel__c IN :validLevels
            ];
        
        String winningApproverRole = null;
        Integer highestPriority = -1;
        
        // Evaluate every single item (both the root data AND the line items)
        for (Map<String, Object> item : items) {
            
            // Grab the name of the product
            String itemName = (String) item.get('name');
            if (itemName == null) itemName = (String) item.get('productname');
            if (itemName == null) itemName = 'ALL'; 
            
            // 👉 NORMALIZATION: Remove hyphens, spaces, and make lowercase for bulletproof matching
            String normalizedItemName = itemName.replaceAll('[-\\s]', '').toLowerCase();
            
            for (Quote_Approval_Matrix__mdt rule : rules) {
                
                // 1. Check Product
                String normalizedProduct = String.isNotBlank(rule.Product__c) ? rule.Product__c.replaceAll('[-\\s]', '').toLowerCase() : '';
                Boolean matchesProduct = (rule.Product__c == 'ALL' || normalizedItemName.contains(normalizedProduct));
                
                // 2. Check Category (Assume blank means it applies to everything)
                String normalizedCategory = String.isNotBlank(rule.Category__c) ? rule.Category__c.replaceAll('[-\\s]', '').toLowerCase() : '';
                Boolean matchesCategory;
                if (String.isBlank(rule.Category__c) || rule.Category__c.equalsIgnoreCase('All')) {
                    matchesCategory = true;
                } else if (rule.Category__c.equalsIgnoreCase('Graded')) {
                    matchesCategory = normalizedItemName.contains('graded') && !normalizedItemName.contains('nongraded');
                } else {
                    matchesCategory = normalizedItemName.contains(normalizedCategory);
                }
                
                // 3. Check Sub-Component (Assume blank means it applies to everything)
                String normalizedSubComponent = String.isNotBlank(rule.Sub_Component__c) ? rule.Sub_Component__c.replaceAll('[-\\s]', '').toLowerCase() : '';
                Boolean matchesSubComponent = String.isBlank(rule.Sub_Component__c)
                    || rule.Sub_Component__c.equalsIgnoreCase('All')
                    || normalizedItemName.contains(normalizedSubComponent);
                
                // Only evaluate the metrics if ALL relevant product identifiers match the item string
                if (matchesProduct && matchesCategory && matchesSubComponent) {
                    
                    // Force the metadata metric to lowercase (e.g., 'Discount' becomes 'discount')
                    String metricName = rule.Evaluation_Metric__c != null ? rule.Evaluation_Metric__c.toLowerCase() : '';
                    
                    if (item.containsKey(metricName)) {
                        
                        Object rawVal = item.get(metricName);
                        if (rawVal == null || String.valueOf(rawVal).trim() == '' || String.valueOf(rawVal).trim().equalsIgnoreCase('null')) {
                            continue; 
                        }
                        
                        // Safely convert the number to a Decimal
                        Decimal actualValue = 0;
                        try {
                            actualValue = (Decimal) rawVal;
                        } catch (Exception e) {
                            actualValue = Decimal.valueOf(String.valueOf(rawVal).trim());
                        }
                        
                        Decimal maxBound = rule.Max_value__c != null ? rule.Max_value__c : 999999999;
                        Decimal minBound = rule.Min_value__c != null ? rule.Min_value__c : -999999999;
                        
                        // Does the line item fall into this rule's threshold?
                        if (actualValue >= minBound && actualValue <= maxBound) {
                            String targetRoleName = rule.Approver__c;
                            
                            // 👉 PRIORITY ESCALATION ENGINE
                            Integer priority = 1;
                            if (targetRoleName.containsIgnoreCase('Utkarsh') || targetRoleName.containsIgnoreCase('CMD') || targetRoleName.containsIgnoreCase('Director')) {
                                priority = 10;
                            } else if (targetRoleName.containsIgnoreCase('HOD') || targetRoleName.containsIgnoreCase('Head')) {
                                priority = 5;
                            }
                            if (rule.Escalation__c == true) {
                                priority = 20;
                            }
                            
                            // Utkarsh (10) will always overwrite HOD (5)
                            if (priority > highestPriority) {
                                highestPriority = priority;
                                winningApproverRole = targetRoleName;
                                System.debug('Escalating Approval to: ' + winningApproverRole + ' due to item: ' + itemName + ' | Value: ' + actualValue);
                            }
                        }
                    }
                }
            }
        }
        
        // Find the User ID for the winning role
        if (winningApproverRole != null) {
            
            // 👉 NEW: The "SELF" Keyword Interceptor
            if (winningApproverRole.equalsIgnoreCase('SELF')) {
                System.debug('Auto-assigning approval to the Submitter!');
                return UserInfo.getUserId();
            }
            
            // Normal routing for Managers
            List<User> targetUsers = [SELECT Id, Name FROM User WHERE UserRole.Name = :winningApproverRole AND IsActive = true LIMIT 1];
            if (!targetUsers.isEmpty()) {
                return targetUsers[0].Id;
            } else {
                System.debug('FAIL: No active user found holding the role "' + winningApproverRole + '"');
                return 'FAIL_NO_USER_FOR_ROLE'; 
            }
        }
        
        return 'FAIL_NO_RULES_MATCHED'; 
    }
    @AuraEnabled
    public static List<Id> getSubordinateUserIds() {
        Id currentUserId = UserInfo.getUserId();
        List<Id> authorizedUserIds = new List<Id>{ currentUserId }; // Always include the current user
            
            // 1. Get the current user's role
            List<User> currentUser = [SELECT UserRoleId FROM User WHERE Id = :currentUserId LIMIT 1];
        if (currentUser.isEmpty() || currentUser[0].UserRoleId == null) {
            return authorizedUserIds; // If they have no role, they only see their own approvals
        }
        
        // 2. Fetch all subordinate roles recursively
        Set<Id> currentRoleIds = new Set<Id>{ currentUser[0].UserRoleId };
            Set<Id> allSubordinateRoleIds = new Set<Id>();
        
        // Loop down the role hierarchy tree
        while (!currentRoleIds.isEmpty() && Limits.getQueries() < 90) {
            Map<Id, UserRole> childRoles = new Map<Id, UserRole>([
                SELECT Id FROM UserRole WHERE ParentRoleId IN :currentRoleIds
            ]);
            currentRoleIds = childRoles.keySet();
            allSubordinateRoleIds.addAll(currentRoleIds);
        }
        
        // 3. Find all active users sitting in those subordinate roles
        if (!allSubordinateRoleIds.isEmpty()) {
            List<User> subordinateUsers = [
                SELECT Id FROM User 
                WHERE UserRoleId IN :allSubordinateRoleIds 
                AND IsActive = true
            ];
            
            for (User u : subordinateUsers) {
                authorizedUserIds.add(u.Id);
            }
        }
        
        return authorizedUserIds; // Returns a list: [Your Id, Subordinate 1 Id, Subordinate 2 Id, ...]
    }
    
    /**
* Finalizes the Quote: Updates the Opportunity fields, purges previous automated files,
* and attaches documents defined in Custom Metadata for the Quote's Department.
*/
    @AuraEnabled
    public static void finalizeQuoteAndAttachDocs(Id opportunityId, Id quoteId, String calledfrom) {
    try {
        // 1. Fetch Active Quote
        Quote activeQuote = [SELECT Id, QuoteNumber, Quote_Reference__c, Revision_No__c,
                                    Original_Quote__c, Original_Quote__r.QuoteNumber,
                                    Original_Quote__r.Quote_Reference__c,
                                    Final_Quote_Amount__c, submition_date__c, LastModifiedDate,
                                    Name, Quote_Value__c
                            FROM Quote
                            WHERE Id = :quoteId LIMIT 1];

        // 2. Parse Department Name from Quote_Value__c JSON
        String targetDepartment = activeQuote.Name;
        if (String.isNotBlank(activeQuote.Quote_Value__c)) {
            try {
                Map<String, Object> quoteValueMap = (Map<String, Object>) JSON.deserializeUntyped(activeQuote.Quote_Value__c);
                if (quoteValueMap.get('_Saved_Template_Name') != null) {
                    targetDepartment = String.valueOf(quoteValueMap.get('_Saved_Template_Name'));
                }
            } catch (Exception jsonEx) {
                // Fallback to activeQuote.Name on parsing failure
            }
        }

        // 2b. Build the quote reference for file naming (no DML, safe before getContent())
        String quoteRef = activeQuote.Quote_Reference__c;
        if (String.isBlank(quoteRef)) {
            String dept = deptAbbreviation(targetDepartment);
            String fy   = currentFinancialYear();
            Integer rev = (activeQuote.Revision_No__c == null) ? 0 : Integer.valueOf(activeQuote.Revision_No__c);

            if (rev > 0 && activeQuote.Original_Quote__c != null) {
                String rootRef = activeQuote.Original_Quote__r.Quote_Reference__c;
                if (String.isNotBlank(rootRef)) {
                    quoteRef = rootRef.replaceAll('/R\\d+$', '') + '/R' + rev;
                } else {
                    quoteRef = 'UIL/' + dept + '/' + fy + '/' + activeQuote.Original_Quote__r.QuoteNumber + '/R' + rev;
                }
            } else {
                quoteRef = 'UIL/' + dept + '/' + fy + '/' + activeQuote.QuoteNumber;
                if (rev > 0) {
                    quoteRef += '/R' + rev;
                }
            }
        }
        String refForFileName = quoteRef; //.replace('/', '-');

        // 3. Query Document Mappings
        List<Document_Template_Mapping__mdt> mappings = [SELECT Excel_VF_Page__c, PDF_VF_Page__c, Word_VF_Page__c, Template_Type__c, offer_document__c
                                                        FROM Document_Template_Mapping__mdt
                                                        WHERE Department__c = :targetDepartment];

        // 4. Prepare Files and Track Offer PDFs
        List<ContentVersion> filesToInsert = new List<ContentVersion>();
        List<ContentVersion> offerPdfVersions = new List<ContentVersion>();   // CHANGED: replaces offerDocTitles

        for (Document_Template_Mapping__mdt mapRule : mappings) {
            String title = refForFileName;

            if (String.isNotBlank(mapRule.Excel_VF_Page__c)) {
                filesToInsert.add(createContentVersion(mapRule.Excel_VF_Page__c, activeQuote.Id, title + '.xls'));
            }
            if (String.isNotBlank(mapRule.PDF_VF_Page__c)) {
                ContentVersion pdfCv = createContentVersion(mapRule.PDF_VF_Page__c, activeQuote.Id, title + '.pdf');
                filesToInsert.add(pdfCv);
                // CHANGED: only PDFs from rules with offer_document__c checked are tracked
                if (mapRule.offer_document__c == true) {
                    offerPdfVersions.add(pdfCv);
                }
            }
            if (String.isNotBlank(mapRule.Word_VF_Page__c)) {
                filesToInsert.add(createContentVersion(mapRule.Word_VF_Page__c, activeQuote.Id, title + '.doc'));
            }
        }

        // 5. Cleanup Previous Quote Files on Opportunity
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :opportunityId];
        if (!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink link : links) {
                docIds.add(link.ContentDocumentId);
            }

            String titleEndPattern = '%_' + activeQuote.QuoteNumber + '%';
            List<ContentDocument> oldDocs = [SELECT Id FROM ContentDocument
                                            WHERE Id IN :docIds
                                            AND (Title LIKE :titleEndPattern
                                                OR Title LIKE 'Finalized_%'
                                                OR Description = 'Generated via Quote Finalization')];
            if (!oldDocs.isEmpty()) {
                delete oldDocs;
            }
        }

        // 6. Insert ContentVersions & Create Document Links
        List<String> offerDocIds = new List<String>();

        if (!filesToInsert.isEmpty()) {
            insert filesToInsert;

            // CHANGED: Ids are populated on the same record instances after insert
            Set<Id> offerCvIds = new Set<Id>();
            for (ContentVersion ocv : offerPdfVersions) {
                offerCvIds.add(ocv.Id);
            }

            Set<Id> insertedCvIds = new Map<Id, ContentVersion>(filesToInsert).keySet();
            List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();

            for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :insertedCvIds]) {
                newLinks.add(new ContentDocumentLink(
                    LinkedEntityId = opportunityId,
                    ContentDocumentId = cv.ContentDocumentId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));

                // CHANGED: only files generated by offer_document__c = true rules
                if (offerCvIds.contains(cv.Id)) {
                    offerDocIds.add(cv.ContentDocumentId);
                }
            }
            insert newLinks;
        }

        // 7. Update Opportunity Details and Offer Document IDs
        Date updatedCloseDate = (activeQuote.LastModifiedDate != null ? activeQuote.LastModifiedDate.date() : Date.today()).addDays(15);

        update new Opportunity(
            Id = opportunityId,
            SyncedQuoteId = activeQuote.Id,
            Amount = activeQuote.Final_Quote_Amount__c,
            StageName = 'Negotiation',
            CloseDate = updatedCloseDate,
            Final_Quote_Document_ID__c = !offerDocIds.isEmpty() ? String.join(offerDocIds, ',') : null
        );

        if (calledfrom == 'finalizeQuoteButton') {
            update new Quote(
                Id = activeQuote.Id,
                Finalized_Quote__c = true
            );
        }

    } catch (Exception ex) {
        throw new AuraHandledException('Finalization Error: ' + ex.getMessage());
    }
}/**
* Helper to build ContentVersion structures and fetch Visualforce page blobs safely
*/
    private static ContentVersion createContentVersion(String vfPageUrl, Id quoteId, String fileName) {
        PageReference pageRef = new PageReference(vfPageUrl);
        pageRef.getParameters().put('id', quoteId);
        
        Blob fileBlob;
        try {
            fileBlob = Test.isRunningTest() ? Blob.valueOf('Test Unit Blob') : pageRef.getContent();
        } catch (Exception e) {
            fileBlob = Blob.valueOf('Error parsing file content buffer: ' + e.getMessage());
        }
        
        return new ContentVersion(
            Title = fileName.substringBeforeLast('.'), // Sets title to "Template_Type__c_QuoteNumber"
            PathOnClient = fileName,
            VersionData = fileBlob,
            Description = 'Generated via Quote Finalization'
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // COST SHEET SUPPORT - returns one quote's saved Quote_Value__c JSON so the
    // costSheetGenerator LWC can build a traceable cost sheet. Read-only.
    // Reetabrata (13th July 2026)
    // ═══════════════════════════════════════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static String getQuoteValueJson(Id quoteId) {   // Reetabrata (13th July 2026)
        try {
            Quote q = [SELECT Quote_Value__c FROM Quote WHERE Id = :quoteId LIMIT 1];
            return q.Quote_Value__c;
        } catch (Exception e) {
            return null;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // QUOTE REFERENCE - Deepanjan (21st July 2026)
    // Builds and stores Quote_Reference__c in the format:
    //     UIL/<Dept>/<FY>/<QuoteNo>[/R<n>]
    // e.g.  UIL/HM/26-27/00005699        (R0 - no /R part)
    //       UIL/HM/26-27/00005699/R1     (revision)
    // Called from the LWC right after the quote is inserted (when QuoteNumber
    // finally exists) and again whenever a revision is created. "department" is
    // the template picklist value the LWC already holds (e.g. "High Mast -
    // Department"); the map below reduces it to the abbreviation. FY is the
    // Indian financial year (Apr-Mar) as NN-NN.
    // ═══════════════════════════════════════════════════════════════════════
    @AuraEnabled
    public static String generateQuoteReference(Id quoteId, String department) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        
                Quote q = [
            SELECT Id, QuoteNumber, Revision_No__c, Original_Quote__c,
                   Original_Quote__r.QuoteNumber, Original_Quote__r.Quote_Reference__c
            FROM Quote WHERE Id = :quoteId LIMIT 1
        ];
        
        String dept = deptAbbreviation(department);
        String fy   = currentFinancialYear();
        Integer rev = (q.Revision_No__c == null) ? 0 : Integer.valueOf(q.Revision_No__c);
        
                String ref;
        if (rev > 0 && q.Original_Quote__c != null) {
            // revision -> family root- reference + /Rn
            String rootRef = q.Original_Quote__r.Quote_Reference__c;
            if (String.isNotBlank(rootRef)) {
                ref = rootRef.replaceAll('/R\\d+$', '') + '/R' + rev;
            } else {
                ref = 'UIL/' + dept + '/' + fy + '/' + q.Original_Quote__r.QuoteNumber + '/R' + rev;
            }
        } else {
            ref = 'UIL/' + dept + '/' + fy + '/' + q.QuoteNumber;
            if (rev > 0) {
                ref += '/R' + rev;   // R0 shows no /R part, per spec
            }
        }
        
        // write only if changed, to avoid a needless DML / trigger loop
        Quote toUpdate = new Quote(Id = quoteId, Quote_Reference__c = ref);
        update toUpdate;
        return ref;
    }
    
    // Department picklist value -> abbreviation. High Mast (any sub-type) = HM;
    // Core stays lower-case "core" per Deepanjan. Extend here (or move to Custom
    // Metadata later) when new departments are added. Deepanjan (21st July 2026)
    private static String deptAbbreviation(String department) {
        String d = (department == null) ? '' : department.toLowerCase();
        if (d.contains('high mast'))          return 'HM';
        if (d.contains('crash barrier'))      return 'CB';
        if (d.contains('hdpe'))               return 'HDPE';
        if (d.contains('peb'))                return 'PEB';
        if (d.contains('solar'))              return 'SS';
        if (d.contains('steel tubular'))      return 'STP';
        if (d.contains('steel pipe'))         return 'SP(D)';
        if (d.contains('telecom'))            return 'Telecom';
        if (d.contains('transmission'))       return 'TLT & SSS';
        if (d.contains('core'))               return 'CORE';
        // Unknown department: first letters of each word, upper-cased, so the
        // reference is still generated instead of failing.
        String abbr = '';
        for (String w : (department == null ? '' : department.replace('- Department','').trim()).split('\\s+')) {
            if (String.isNotBlank(w)) abbr += w.substring(0,1).toUpperCase();
        }
        return String.isBlank(abbr) ? 'GEN' : abbr;
    }
    
    // Indian financial year (1 Apr - 31 Mar) as "NN-NN", e.g. 26-27.
    // Deepanjan (21st July 2026)
    private static String currentFinancialYear() {
        Date today = Date.today();
        Integer y = today.year();
        Integer startYr = (today.month() >= 4) ? y : y - 1;
        Integer endYr   = startYr + 1;
        String s = String.valueOf(Math.mod(startYr, 100));
        String e = String.valueOf(Math.mod(endYr, 100));
        if (s.length() == 1) s = '0' + s;
        if (e.length() == 1) e = '0' + e;
        return s + '-' + e;
    }
    
    /* ═══════════ OFFER TOTAL CAPTURE — quote approval ═══════════
Reads the department's own offer controller directly. Every one of these
controllers does its work in the constructor and reads no URL parameters,
so building it here yields exactly the figure its PDF prints - without
rendering the page. That keeps the live offer documents untouched.
Deepanjan (3rd August 2026) */
    
    @AuraEnabled
    public static void captureOfferTotal(Id quoteId, Id opportunityId) {
        try {
            Decimal total = resolveOfferTotal(quoteId);
            
            if (total != null) {
                update new Quote(Id = quoteId, Final_Quote_Amount__c = total);
            }
            
            Opportunity opp = [SELECT Id, StageName, CloseDate, Customer_Journey__c
                               FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            Boolean changed = false;
            if (total != null) { opp.Amount = total; changed = true; }
            if (opp.StageName == 'Nurture' && opp.Customer_Journey__c == 'Direct Business') {
                opp.StageName = 'Negotiation'; changed = true;
            }
            if (changed) update opp;
        } catch (Exception e) {
            throw new AuraHandledException('Offer capture failed: ' + e.getMessage());
        }
    }
    
    public static Decimal resolveOfferTotal(Id quoteId) {
        Quote q = [SELECT Id, Name, Quote_Value__c FROM Quote WHERE Id = :quoteId LIMIT 1];
        
        // Department resolution — same rule finalize uses.
        String dept = q.Name;
        if (String.isNotBlank(q.Quote_Value__c)) {
            try {
                Map<String, Object> qv = (Map<String, Object>) JSON.deserializeUntyped(q.Quote_Value__c);
                if (qv.get('_Saved_Template_Name') != null) {
                    dept = String.valueOf(qv.get('_Saved_Template_Name'));
                }
            } catch (Exception jsonEx) {}
        }
        
        ApexPages.StandardController sc = new ApexPages.StandardController(q);
        
        try {
            if (dept != null && dept.containsIgnoreCase('Core')) {
                return new CoreOfferLetterController(sc).grandTotalIncGST;
            }
            // STP — one running grand total, already summed in the constructor.
            if (dept.containsIgnoreCase('Steel Tubular Pole')) {
                return new QuoteExportControllerForSTP(sc).totalAmount;
            }
            // HDPE — the PDF prints a "Total Amount (with GST)" per table plus the
            // Block B final amount; add them the same way.
            if (dept.containsIgnoreCase('HDPE')) {
                QuoteControllerforHDPE h = new QuoteControllerforHDPE(sc);
                Decimal t = 0;
                if (h.tables != null) {
                    for (QuoteControllerforHDPE.TableWrapper tw : h.tables) {
                        t += (tw.tableSubTotal == null ? 0 : tw.tableSubTotal)
                            + (tw.gstAmount == null ? 0 : tw.gstAmount)
                            + (tw.transportationCharge == null ? 0 : tw.transportationCharge);
                    }
                }
                t += (h.blockBFinalAmount == null ? 0 : h.blockBFinalAmount);
                return t.setScale(2);
            }
            // Crash Barrier - mirror the offer page's rounding boundaries. The page prints one
            // total per section, each rounded to 2 dp on screen, so summing rounded section
            // totals is the only way to land on the printed figure to the paisa; multiplying
            // the whole base once left it short. Deepanjan (3rd August 2026)
            if (dept.containsIgnoreCase('Crash Barrier')) {
                CrashBarrierQuoteController cb = new CrashBarrierQuoteController(sc);
                
                // Flag ON keeps every rate raw and the page adds the uplift per section.
                // Flag OFF has it folded into the rates already, so no uplift here.
                Decimal f = (cb.showSeperateInterest == true && cb.intrestfactor != null)
                    ? cb.intrestfactor
                    : 1.00;
                
                Decimal t = 0;
                
                if (cb.lineItems != null) {
                    for (Map<String, Object> li : cb.lineItems) {
                        String nm = li.get('name') == null ? '' : String.valueOf(li.get('name'));
                        String up = nm.toUpperCase();
                        
                        // Accessory / Misc / Additional Misc print ONE combined section total
                        // lower down the page, so they are added after this loop, not per line.
                        if (up.startsWith('ACCESSORY:') || up.startsWith('MISC:') || up.startsWith('ADD')) {
                            continue;
                        }
                        
                        Decimal qty  = cbNum(li.get('quantity'));
                        Decimal rate = cbNum(li.get('unitPrice'));
                        
                        // Pedestrian Guard Rail is the one section whose AMOUNT column prints
                        // unitPrice as the whole line total - its RATE column is unitPrice / qty.
                        Decimal base = up.contains('PEDESTRIAN GUARD RAIL') ? rate : (qty * rate);
                            
                            Decimal fr = cbNum(cb.jsonData.get(cbFreightKey(up)));
                        
                        t += ((base + fr) * f).setScale(2, RoundingMode.HALF_UP);
                    }
                }
                
                t += ((cbNum(cb.totalAccessoriesAmount) + cbNum(cb.jsonData.get('acc_section_fvf')))  * f).setScale(2, RoundingMode.HALF_UP);
                t += ((cbNum(cb.totalMiscAmount)        + cbNum(cb.jsonData.get('misc_section_fvf'))) * f).setScale(2, RoundingMode.HALF_UP);
                t += ((cbNum(cb.totalAddlMiscAmount)    + cbNum(cb.jsonData.get('add_misc_fvf')))     * f).setScale(2, RoundingMode.HALF_UP);
                
                return t.setScale(2);
            }
            
            // Transmission Tower - the page prints only unit rates, but each tower row
            // already carries totalPrice (price x quantity), computed in the constructor;
            // summing those gives the real order value. The TOTAL row is commented out in
            // the controller, so no row is itself a total and nothing double-counts.
            // Substation rows carry no quantity and no line total - that document is a pure
            // rate schedule - so for now their printed unit prices are summed as a
            // placeholder, pending the client's decision on what such a quote is worth.
            // Deepanjan (4th August 2026)
            if (dept.containsIgnoreCase('Transmission')) {
                TransmissionTowerOfferController tt = new TransmissionTowerOfferController(sc);
                Decimal t = 0;
                
                // towerTables is a getter that builds lazily on first call, not a field.
                List<TransmissionTowerOfferController.TowerPriceTable> tbls = tt.getTowerTables();
                if (tbls != null) {
                    for (TransmissionTowerOfferController.TowerPriceTable tbl : tbls) {
                        if (tbl.rows == null) continue;
                        for (TransmissionTowerOfferController.TowerRow r : tbl.rows) {
                            if (r.isTotal == true) continue;
                            t += parseMoney(r.totalPrice);
                        }
                    }
                }
                
                // Substation - sum exactly the Unit Price cells the document prints. This
                // builder keys off the 'PRICE MODEL - SUBSTATION' lines, so on a Tower quote
                // it returns an empty list and the figure above is untouched.
                List<TransmissionTowerOfferController.SubstationPriceTable> subs = tt.getSubstationTables();
                if (subs != null) {
                    for (TransmissionTowerOfferController.SubstationPriceTable stbl : subs) {
                        if (stbl.sections == null) continue;
                        for (TransmissionTowerOfferController.SubstationSection sec : stbl.sections) {
                            if (sec.rows == null) continue;
                            for (TransmissionTowerOfferController.SubstationRow r : sec.rows) {
                                t += parseMoney(r.unitPrice);
                            }
                        }
                    }
                }
                
                return t > 0 ? t.setScale(2) : null;
            }
            
            // Telecom — the document has no grand total; the money column is
            // "Total Basic Rate" on each tower row. mglRows (freight/loadability) and
            // rptRows (rate per ton) are informational, not line amounts, so they are
            // excluded. totalBasicRate is a formatted String, hence parseMoney.
            // Deepanjan (3rd August 2026)
            
            if (dept.containsIgnoreCase('Telecom')) {
                TelecomDocumentController tc = new TelecomDocumentController(sc);
                Decimal t = 0;
                if (tc.towerDetailGroups != null) {
                    for (TelecomDocumentController.TowerGroup g : tc.towerDetailGroups) {
                        if (g.rows == null) continue;
                        for (TelecomDocumentController.TowerRow r : g.rows) {
                            t += parseMoney(r.totalBasicRate);
                        }
                    }
                }
                return t.setScale(2);
            }
            
            // Solar Structure - do NOT instantiate SolarQuoteOfferController here. Its
            // constructor calls stdController.addFields(...), which only works when the
            // StandardController is page-bound; from Apex it throws and the capture silently
            // produced nothing. Every figure needed is in the saved JSON, so read it straight
            // from there and leave that prod controller untouched.
            // Deepanjan (4th August 2026)
            if (dept.containsIgnoreCase('Solar')) {
                return solarOfferTotal(q.Quote_Value__c);
            }
            
            // High Mast - there was no branch, so every High Mast approval fell through to
            // null and neither Final_Quote_Amount__c nor Opportunity.Amount ever moved.
            // The Single Scope controller (HighMastSOWController, the "Statement of Work"
            // page) does all of its work in the constructor and reads no URL parameter, so
            // instantiating it yields exactly the figure that PDF prints. Its grandTotal is
            // a formatted String, so the line rows are summed here with the same per-line
            // 2 dp rounding the constructor uses - landing on the printed total to the
            // paisa. Returns null, never 0, when the quote produced no rows, so an empty
            // quote can never overwrite the Amount with zero. Deepanjan (3rd September 2026)
            if (dept.containsIgnoreCase('High Mast')) {
                HighMastSOWController hm = new HighMastSOWController(sc);
                if (hm.lineItems == null || hm.lineItems.isEmpty()) return null;
                Decimal t = 0;
                for (HighMastSOWController.LineItemWrapper w : hm.lineItems) {
                    if (w.totalAmountRaw != null) t += w.totalAmountRaw.setScale(2, RoundingMode.HALF_UP);
                }
                return t <= 0 ? null : t.setScale(2, RoundingMode.HALF_UP);
            }
            
            if (dept.containsIgnoreCase('Steel Pipe')) {
                SteelPipesQuoteController sp = new SteelPipesQuoteController(sc);
                Decimal t = (sp.isExport == true) ? sp.totalExportFobInr : sp.totalFinalAmount;
                return (t == null || t <= 0) ? null : t.setScale(2, RoundingMode.HALF_UP);
            }
            
            if (dept.containsIgnoreCase('PEB')) {
                QuoteExportController peb = new QuoteExportController(sc);
                Decimal t = parseMoney(peb.supplyPriceWithGst);
                return (t == null || t <= 0) ? null : t.setScale(2, RoundingMode.HALF_UP);
            }
            
        } catch (Exception ex) {
            System.debug('Offer total failed for ' + dept + ': ' + ex.getMessage());
        }
        return null;   
    }
    
    /* The document controllers format money into Strings ("1,23,456.00"),
so read them back tolerantly. */
    public static Decimal parseMoney(String raw) {
        if (String.isBlank(raw)) return 0;
        String c = raw.replaceAll('[^0-9.\\-]', '');
        if (String.isBlank(c) || c == '-' || c == '.') return 0;
        try { return Decimal.valueOf(c); } catch (Exception e) { return 0; }
    }
    
    // Null / blank / non-numeric safe read. Deepanjan (3rd August 2026)
    public static Decimal cbNum(Object v) {
        if (v == null) return 0;
        String s = String.valueOf(v).trim();
        if (s == '') return 0;
        try { return Decimal.valueOf(s); } catch (Exception e) { return 0; }
    }
    
    // The same section -> freight key map crashBarrierVFPage uses, so the Apex adds
    // freight into exactly the same rounding bucket as the printed section total.
    // Deepanjan (3rd August 2026)
    public static String cbFreightKey(String up) {
        Boolean thrie = up.contains('THRIE');
        if (up.contains('NATRAX'))                return thrie ? 'tb_natrax_fvf' : 'wb_natrax_fvf';
        if (up.contains('ALKA'))                  return thrie ? 'tb_alka_fvf'   : 'wb_alka_fvf';
        if (up.contains('TRANSPOLIS'))            return thrie ? 'tb_trans_fvf'  : 'wb_trans_fvf';
        if (up.contains('NOISE BARRIER'))         return up.contains('REFLECTIVE') ? 'r_s_fvf' : 'a_s_fvf';
        if (up.contains('PEDESTRIAN GUARD RAIL')) return 'PGR_full_vehicle_freight';
        if (up.contains('RAILWAY'))               return up.contains('NON')
            ? 'rlw_non_graded_full_Vehicle_freight'
            : 'rlw_full_Vehicle_freight';
        if (up.contains('NON-SPACER'))            return thrie ? 'ns_thrie_beam_section_full_Vehicle_freight'
            : 'ns_w_beam_section_full_Vehicle_freight';
        if (up.contains('CONVENTIONAL')) {
            if (up.contains('SSSB')) return thrie ? 'Thrie_SSSB_full_Vehicle_freight' : 'w_SSSB_w_beam_full_Vehicle_freight';
            if (up.contains('SSDB')) return thrie ? 'Thrie_SSDB_full_Vehicle_freight' : 'w_SSDB_w_beam_full_Vehicle_freight';
            if (up.contains('DSSB')) return thrie ? 'Thrie_DSSB_full_Vehicle_freight' : 'w_DSSB_w_beam_full_Vehicle_freight';
            if (up.contains('DSDB')) return thrie ? 'Thrie_DSDB_full_Vehicle_freight' : 'w_DSDB_w_beam_full_Vehicle_freight';
        }
        return null;   // unknown section -> freight 0, base still counted
    }
    /* Solar Structure offer total.
*
* Weight mode quotes a rate per MT against Total_Weight__c; Pcs mode quotes a
* piece rate against Quantity__c. Unit_Price__c already carries freight
* (cost + freight = MT rate, x unit weight = piece rate), so nothing is added
* on top of it.
*
* The two tables on SolarStructureQuotePDF round differently, and the captured
* figure has to land on what the document prints:
*   Weight table - both columns are {0, number, #,##0}, i.e. whole rupees, so
*                  the rate is rounded before it is multiplied.
*   Pcs table    - money columns are {0, number, #,##0.00} and it prints
*                  (unitWeight x unitCost) x quantity, which is exactly
*                  Unit_Price__c x quantity, so no rounding is applied.
* Visualforce number formatting goes through Java DecimalFormat, whose default
* rounding is HALF_EVEN - hence that mode rather than HALF_UP.
* Deepanjan (4th August 2026)
*/
    public static Decimal solarOfferTotal(String quoteValueJson) {
        if (String.isBlank(quoteValueJson)) return null;
        
        Map<String, Object> jd;
        try {
            jd = (Map<String, Object>) JSON.deserializeUntyped(quoteValueJson);
        } catch (Exception e) {
            System.debug('Solar offer total: JSON parse failed - ' + e.getMessage());
            return null;
        }
        
        Object cfgObj = jd.get('_configuredSolarStructure');
        if (!(cfgObj instanceof Map<String, Object>)) return null;
        Map<String, Object> cfg = (Map<String, Object>) cfgObj;
        
        Object linesObj = cfg.get('Lines');
        if (!(linesObj instanceof List<Object>)) return null;
        
        // Header key wins, the configured copy is the fallback, and Weight is the
        // controller's own default when neither is set.
        Object uomObj = jd.get('unit_of_measurement');
        String uom = (uomObj == null) ? '' : String.valueOf(uomObj).trim();
        if (String.isBlank(uom) || uom == 'null') {
            Object cfgUom = cfg.get('Unit_Of_Measurement__c');
            uom = (cfgUom == null) ? '' : String.valueOf(cfgUom).trim();
        }
        Boolean isWeight = String.isBlank(uom) || !uom.containsIgnoreCase('Pcs');
        
        Decimal t = 0;
        
        for (Object lineObj : (List<Object>) linesObj) {
            if (!(lineObj instanceof Map<String, Object>)) continue;
            Map<String, Object> line = (Map<String, Object>) lineObj;
            
            Decimal rate = cbNum(line.get('Unit_Price__c'));
            Decimal mult;
            
            if (isWeight) {
                rate = rate.setScale(0, RoundingMode.HALF_EVEN);   // as printed
                mult = cbNum(line.get('Total_Weight__c'));
            } else {
                mult = cbNum(line.get('Quantity__c'));
                if (mult == 0) mult = 1;    // mirrors the controller's quantity default
            }
            
            t += (rate * mult).setScale(2, RoundingMode.HALF_UP);
        }
        
        return t > 0 ? t.setScale(2) : null;
    }
    
    /* APPLY-time capture. Same figure, but only the Quote field is written -
no Opportunity.Amount, no stage rule; those stay on approval alone.
Failures are swallowed on purpose: a save must never break because the
capture could not resolve a total. Deepanjan (4th August 2026) */
    @AuraEnabled
    public static void captureQuoteTotal(Id quoteId) {
        try {
            Decimal total = resolveOfferTotal(quoteId);
            if (total != null) {
                update new Quote(Id = quoteId, Final_Quote_Amount__c = total);
            }
        } catch (Exception e) {
            System.debug('Quote total capture failed: ' + e.getMessage());
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // ESCALATION ENGINE — metadata-driven two-stage approval
    // ═══════════════════════════════════════════════════════════════════════
    public class EscalationResult {
        @AuraEnabled public String required;   // 'true' or 'false'
        @AuraEnabled public String targetId;   // User Id to escalate to
        @AuraEnabled public String message;    // diagnostic only
    }
    
    @AuraEnabled
    public static EscalationResult checkEscalationRequired(Id quoteId, String department, String itemsJson) {
        EscalationResult result = new EscalationResult();
        result.required = 'false';
        result.targetId = '';
        
        if (quoteId == null || String.isBlank(department)) {
            return result;
        }
        
        // 1. Resolve the ORIGINAL submitter's role
        String submitterRole = 'No_Role';
        List<Quote> qList = [
            SELECT CreatedBy.UserRole.Name 
            FROM Quote WHERE Id = :quoteId LIMIT 1
        ];
        if (!qList.isEmpty() && qList[0].CreatedBy != null && qList[0].CreatedBy.UserRole != null) {
            submitterRole = qList[0].CreatedBy.UserRole.Name;
        }
        
        // 2. Deserialize payload exactly like determineApprover
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        Object deserialized = JSON.deserializeUntyped(itemsJson);
        
        if (deserialized instanceof List<Object>) {
            for (Object obj : (List<Object>) deserialized) {
                Map<String, Object> rawMap = (Map<String, Object>) obj;
                Map<String, Object> lowerCaseMap = new Map<String, Object>();
                for (String key : rawMap.keySet()) {
                    lowerCaseMap.put(key.toLowerCase(), rawMap.get(key));
                }
                items.add(lowerCaseMap);
            }
        } else if (deserialized instanceof Map<String, Object>) {
            Map<String, Object> payloadMap = (Map<String, Object>) deserialized;
            Map<String, Object> lowerRoot = new Map<String, Object>();
            for (String key : payloadMap.keySet()) {
                lowerRoot.put(key.toLowerCase(), payloadMap.get(key));
            }
            Object dynamicName = payloadMap.get('_Dynamic_Product_Name');
            lowerRoot.put('name', dynamicName != null ? String.valueOf(dynamicName) : 'ALL');
            items.add(lowerRoot);
            
            List<Object> rawItems = new List<Object>();
            if (payloadMap.containsKey('_Final_Apex_Lines')) {
                rawItems = (List<Object>) payloadMap.get('_Final_Apex_Lines');
            } else if (payloadMap.containsKey('_Saved_Table_Rows')) {
                rawItems = (List<Object>) payloadMap.get('_Saved_Table_Rows');
            }
            if (rawItems != null) {
                for (Object obj : rawItems) {
                    Map<String, Object> rawMap = (Map<String, Object>) obj;
                    Map<String, Object> lowerCaseMap = new Map<String, Object>();
                    for (String key : rawMap.keySet()) {
                        lowerCaseMap.put(key.toLowerCase(), rawMap.get(key));
                    }
                    items.add(lowerCaseMap);
                }
            }
        }
        
        List<String> validLevels = new List<String>{ submitterRole, 'ALL' };
            
            List<Quote_Approval_Matrix__mdt> rules = [
                SELECT Approver__c, Min_value__c, Max_value__c, Product__c, Evaluation_Metric__c,
                Escalation__c
                FROM Quote_Approval_Matrix__mdt
                WHERE Department__c = :department
                AND Submitterlevel__c IN :validLevels
            ];
        
        String winningApproverRole = null;
        Integer highestPriority = -1;
        Boolean escalationFound = false;
        
        for (Map<String, Object> item : items) {
            String itemName = (String) item.get('name');
            if (itemName == null) itemName = (String) item.get('productname');
            if (itemName == null) itemName = 'ALL';
            
            for (Quote_Approval_Matrix__mdt rule : rules) {
                if (rule.Product__c == 'ALL' || itemName.containsIgnoreCase(rule.Product__c)) {
                    String metricName = rule.Evaluation_Metric__c != null ? rule.Evaluation_Metric__c.toLowerCase() : '';
                    if (item.containsKey(metricName)) {
                        Object rawVal = item.get(metricName);
                        if (rawVal == null || String.valueOf(rawVal).trim() == '' 
                            || String.valueOf(rawVal).trim().equalsIgnoreCase('null')) {
                                continue;
                            }
                        Decimal actualValue = 0;
                        try {
                            actualValue = (Decimal) rawVal;
                        } catch (Exception e) {
                            actualValue = Decimal.valueOf(String.valueOf(rawVal).trim());
                        }
                        Decimal maxBound = rule.Max_value__c != null ? rule.Max_value__c : 999999999;
                        Decimal minBound = rule.Min_value__c != null ? rule.Min_value__c : -999999999;
                        
                        if (actualValue >= minBound && actualValue <= maxBound) {
                            String targetRoleName = rule.Approver__c;
                            Integer priority = 1;
                            if (targetRoleName.containsIgnoreCase('Utkarsh') 
                                || targetRoleName.containsIgnoreCase('CMD') 
                                || targetRoleName.containsIgnoreCase('Director')) {
                                    priority = 10;
                                } else if (targetRoleName.containsIgnoreCase('HOD') 
                                           || targetRoleName.containsIgnoreCase('Head')) {
                                               priority = 5;
                                           }
                            if (rule.Escalation__c == true) {
                                priority = 20;
                            }
                            
                            if (priority > highestPriority) {
                                highestPriority = priority;
                                winningApproverRole = targetRoleName;
                                escalationFound = rule.Escalation__c == true;
                            }
                        }
                    }
                }
            }
        }
        
        if (escalationFound) {
            result.required = 'true';
            
            // ALWAYS resolve to Ed — hardcoded, no metadata field needed
            // ALWAYS resolve to Ed by Role — hardcoded, no metadata field needed
            List<User> edUsers = [
                SELECT Id FROM User 
                WHERE UserRole.Name = 'Utkarsh ED' // e.g., 'ED Role' or 'Executive Director'
                AND IsActive = true 
                LIMIT 1
            ];
            
            if (!edUsers.isEmpty()) {
                result.targetId = edUsers[0].Id;
            } else {
                // Fallback: try exact name match or common variations
                List<User> fallback = [
                    SELECT Id FROM User 
                    WHERE (Name = 'Ed' OR Name LIKE '%Edward%' OR Name LIKE '%Eddie%')
                    AND IsActive = true 
                    LIMIT 1
                ];
                if (!fallback.isEmpty()) {
                    result.targetId = fallback[0].Id;
                } else {
                    result.message = 'No active user found for Ed.';
                }
            }
        }
        
        return result;
    }
    
        // ==========================================
    // OFFER PREVIEW AS BYTES — Deepanjan (18th September 2026)
    // Renders the mapped offer VF page to PDF and returns it as base64. The LWC paints it
    // on canvas, so no PDF file ever reaches the browser before approval. Common to every
    // department - the caller passes the PDF_VF_Page__c path from the mapping.
    // ==========================================
    @AuraEnabled
    public static String getQuoteDocumentBase64(Id quoteId, String vfPagePath) {
        if (quoteId == null || String.isBlank(vfPagePath)) {
            throw new AuraHandledException('Missing parameters.');
        }
        // Accept only a bare /apex/PageName - no query string, no host, no traversal.
        String path = vfPagePath.split('\\?')[0].trim();
        if (!Pattern.matches('^/apex/[A-Za-z0-9_]+$', path)) {
            throw new AuraHandledException('Invalid page path.');
        }
        PageReference pr = new PageReference(path);
        pr.getParameters().put('id', quoteId);
        Blob content = Test.isRunningTest() ? Blob.valueOf('%PDF-TEST') : pr.getContentAsPDF();
        return EncodingUtil.base64Encode(content);
    }
}