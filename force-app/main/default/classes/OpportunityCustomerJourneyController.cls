public with sharing class OpportunityCustomerJourneyController {
    private static final String  QUOTE_OBJECT       = 'Quote';
    private static final String  QUOTE_OPP_FIELD    = 'OpportunityId';
    private static final String  QUOTE_AMOUNT_FIELD = 'Final_Quote_Amount__c';
    private static final String  QUOTE_CLOSE_FIELD  = 'ExpirationDate';   // ECD source (req 4 / 8)
    private static final String  QUOTE_STATUS_FIELD = 'Status';
    private static final String  QUOTE_APPROVED     = 'Approved';         // only Approved quotes count

    private static final String  TASKLOG_OPP_FIELD = 'Opportunity__c';
    private static final Integer DEFAULT_EVENT_MINUTES = 60;

    private static final String JOURNEY_DIRECT    = 'Direct Business';
    private static final String JOURNEY_DEALER    = 'Refer to Dealer';
    private static final String STAGE_NURTURE     = 'Nurture';
    private static final String STAGE_NEGOTIATION = 'Negotiation';
    private static final String DEALER_RT_DEVNAME = 'Dealer';

    // Account field now used for dealer<->opportunity department matching.
    // Multi-select picklist: an Opportunity department matches when it is one
    // of the values selected on the Account.
    private static final String ACCOUNT_DEPT_MSP = 'Department_Name_MultiSelect__c';

    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public Option(String l, String v) { label = l; value = v; }
    }

    public class Context {
        @AuraEnabled public String  currentJourney;
        @AuraEnabled public String  stageName;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date    closeDate;
        @AuraEnabled public Id      dealerAccountId;
        @AuraEnabled public Boolean hasQuote = false;          // TRUE only when an Approved quote exists
        @AuraEnabled public Decimal quoteAmount;
        @AuraEnabled public Date    quoteCloseDate;
        @AuraEnabled public Id      dealerRecordTypeId;
        @AuraEnabled public String  departmentName;
        @AuraEnabled public Boolean isFirstUpdate = true;      // exposed so the LWC can reflect gate state

        // Sub Stage (req 9)
        @AuraEnabled public String        subStage;
        @AuraEnabled public Boolean       subStageBlank = true;
        @AuraEnabled public List<Option>  subStageOptions = new List<Option>();
    }

    public class SaveResult {
        @AuraEnabled public Boolean needsFollowUpTask = false;
        @AuraEnabled public String  newStage;
        @AuraEnabled public String  message;
    }

    @AuraEnabled(cacheable=true)
    public static Context getContext(Id opportunityId) {
        Opportunity opp = loadOpp(opportunityId);
        QuoteData qd = getApprovedQuote(opportunityId);

        Context c = new Context();
        c.currentJourney     = opp.Customer_Journey__c;
        c.stageName          = opp.StageName;
        c.amount             = opp.Amount;
        c.closeDate          = opp.CloseDate;
        c.dealerAccountId    = opp.DealerAccount__c;
        c.hasQuote           = qd.exists;
        c.quoteAmount        = qd.amount;
        c.quoteCloseDate     = qd.closeDate;
        c.dealerRecordTypeId = dealerRecordTypeId();
        c.departmentName     = opp.Department_Name__c;
        c.isFirstUpdate      = (opp.isFirstUpdate__c == true);

        // Sub Stage (req 9): only surface the picker when currently blank
        c.subStage           = opp.Sub_Stage__c;
        c.subStageBlank      = String.isBlank(opp.Sub_Stage__c);
        if (c.subStageBlank) {
            for (Schema.PicklistEntry pe : Opportunity.Sub_Stage__c.getDescribe().getPicklistValues()) {
                if (pe.isActive()) {
                    c.subStageOptions.add(new Option(pe.getLabel(), pe.getValue()));
                }
            }
        }
        return c;
    }

    /**
     * Eligible dealers = Dealer-record-type Accounts whose multi-select
     * department picklist INCLUDES the Opportunity's department.
     * Consumed by the LWC to drive an `Id in (...)` filter on the record picker,
     * since lightning-record-picker has no reliable multi-select operator.
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getEligibleDealers(Id opportunityId) {
        Opportunity opp = loadOpp(opportunityId);
        Id rtId = dealerRecordTypeId();
        String dept = opp.Department_Name__c;

        if (String.isBlank(dept)) {
            // No department on the Opportunity -> fall back to record type only.
            return [
                SELECT Id, Name
                FROM Account
                WHERE RecordTypeId = :rtId
                 AND Department_Name_MultiSelect__c INCLUDES (:dept)
                WITH SYSTEM_MODE
                ORDER BY Name
                LIMIT 200
            ];
        }

        return [
            SELECT Id, Name
            FROM Account
            WHERE RecordTypeId = :rtId
              AND Department_Name_MultiSelect__c INCLUDES (:dept)
            WITH SYSTEM_MODE
            ORDER BY Name
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static SaveResult saveCustomerJourney(Id opportunityId, String newJourney,
                                                 Id dealerAccountId, Decimal amount, Date closeDate,
                                                 String subStage) {
        if (String.isBlank(newJourney)) {
            throw handled('Please choose a Customer Journey value.');
        }

        Opportunity opp = loadOpp(opportunityId);
        String current = opp.Customer_Journey__c;

        Opportunity toUpdate = new Opportunity(Id = opportunityId);
        toUpdate.Customer_Journey__c = newJourney;

        // ----- Sub Stage (req 9): mandatory & writable only while blank -----
        if (String.isBlank(opp.Sub_Stage__c)) {
            if (String.isBlank(subStage)) {
                throw handled('Please select a Sub Stage.');
            }
            toUpdate.Sub_Stage__c = subStage;
        }
        // If Sub_Stage__c already has a value, incoming subStage is ignored.

        // isFirstUpdate__c is NOT written here — OpportunityTriggerHandler owns the gate.

        // Only stamp this when the journey genuinely moved. A no-op re-save of the
        // same value should not look like a department change.
        if (newJourney != current) {
            toUpdate.isDepartmentChanged__c = true;
        }

        SaveResult res = new SaveResult();

        if (newJourney == JOURNEY_DEALER) {
            // ----- Refer to Dealer (reqs 6, 7, 8) -----
            if (dealerAccountId == null) {
                throw handled('A Dealer must be selected when referring to a dealer.');
            }
            validateDealer(dealerAccountId, opp.Department_Name__c);
            toUpdate.DealerAccount__c = dealerAccountId;

            // req 6: RTD always moves the Opportunity to Negotiation.
            toUpdate.StageName = STAGE_NEGOTIATION;

            // reqs 7 & 8: EDV/ECD always come from the payload and are required.
            //   - no Approved quote -> user enters them (mandatory)
            //   - Approved quote    -> LWC prefills from the quote, user may edit before saving
            requireDealFields(amount, closeDate);
            toUpdate.Amount    = amount;
            toUpdate.CloseDate = closeDate;

            res.newStage = STAGE_NEGOTIATION;

        } else if (newJourney == JOURNEY_DIRECT) {
            // ----- Direct Business (reqs 1, 3, 4, 5) -----
            toUpdate.DealerAccount__c = null;

            if (opp.StageName == STAGE_NEGOTIATION) {
                QuoteData qd = getApprovedQuote(opportunityId);
                if (qd.exists) {
                    // req 4: stay in Negotiation, populate EDV/ECD from the Approved quote.
                    toUpdate.StageName = STAGE_NEGOTIATION;
                    toUpdate.Amount    = qd.amount;
                    toUpdate.CloseDate = qd.closeDate;
                } else {
                    // req 3: no Approved quote -> fall back to Nurture.
                    // EDV (Amount) is cleared. ECD maps to the standard CloseDate
                    // field, which is REQUIRED on Opportunity and cannot be set to
                    // null, so it is left as-is rather than blanked (see note to user).
                    toUpdate.StageName = STAGE_NURTURE;
                    toUpdate.Amount    = null;
                }
                res.newStage = toUpdate.StageName;
            }
            // reqs 1 & 5: currently in Nurture -> stay in Nurture, no EDV/ECD prompt or change.

            res.needsFollowUpTask = false;

        } else {
            throw handled('Unknown Customer Journey value: ' + newJourney);
        }

        try {
            update toUpdate;
        } catch (DmlException e) {
            throw handled(e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage());
        }
        return res;
    }

    @AuraEnabled
    public static Id createFollowUpTask(Id opportunityId, String taskType, Datetime followUp) {
        if (String.isBlank(taskType)) {
            throw handled('Please choose a task type (Meeting / Call / Visit).');
        }
        if (followUp == null) {
            throw handled('Please choose the follow-up date and time.');
        }

        if (taskType == 'Call') {
            Task t = new Task();
            t.WhatId                 = opportunityId;
            t.Subject                = 'Call Follow-up';
            t.TaskSubtype            = 'Call';
            t.Status                 = 'Open';
            t.Manually_Created__c    = true;
            t.ActivityDate           = followUp.date();
            t.Follow_Up_Date_Time__c = followUp;
            insert t;
            return t.Id;

        } else if (taskType == 'Meeting') {
            Event e = new Event();
            e.WhatId        = opportunityId;
            e.Subject       = 'Meeting Follow-up';
            e.Type          = 'Meeting';
            e.StartDateTime = followUp;
            e.EndDateTime   = followUp.addMinutes(DEFAULT_EVENT_MINUTES);
            insert e;
            return e.Id;

        } else if (taskType == 'Visit') {
            Task_Log__c v = new Task_Log__c();
            v.put(TASKLOG_OPP_FIELD, opportunityId);
            v.Schedule_Date__c = followUp.date();
            v.Is_schedule__c   = true;
            insert v;
            return v.Id;
        }

        throw handled('Unknown task type: ' + taskType);
    }

    /* ========================= helpers ========================= */

    private static Opportunity loadOpp(Id opportunityId) {
        return [
            SELECT Id, Customer_Journey__c, StageName, Amount, CloseDate,
                   DealerAccount__c, Department_Name__c, isFirstUpdate__c, Sub_Stage__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH SYSTEM_MODE
        ];
    }

    /**
     * Validates the chosen dealer:
     *   1. exists / accessible
     *   2. is a Dealer record type
     *   3. its multi-select department picklist INCLUDES the Opportunity department
     */
    private static void validateDealer(Id dealerAccountId, String oppDepartment) {
        List<Account> dealers = [
            SELECT Id, RecordTypeId, Department_Name_MultiSelect__c
            FROM Account
            WHERE Id = :dealerAccountId
            WITH SYSTEM_MODE
        ];
        if (dealers.isEmpty()) {
            throw handled('The selected Dealer could not be found or is not accessible.');
        }

        Account a = dealers[0];
        if (a.RecordTypeId != dealerRecordTypeId()) {
            throw handled('The selected Account is not a Dealer.');
        }

        // When the Opportunity has no department we cannot enforce a match.
        if (String.isBlank(oppDepartment)) {
            return;
        }

        Set<String> dealerDepts = new Set<String>();
        if (String.isNotBlank(a.Department_Name_MultiSelect__c)) {
            for (String v : a.Department_Name_MultiSelect__c.split(';')) {
                dealerDepts.add(v.trim());
            }
        }
        if (!dealerDepts.contains(oppDepartment)) {
            throw handled('The selected Dealer does not serve the Opportunity department (' +
                          oppDepartment + ').');
        }
    }

    private static void requireDealFields(Decimal amount, Date closeDate) {
        if (amount == null || closeDate == null) {
            throw handled('Expected Deal Value and Closure Date are required.');
        }
    }

    private static Id dealerRecordTypeId() {
        Schema.RecordTypeInfo info =
            Account.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName().get(DEALER_RT_DEVNAME);
        return info != null ? info.getRecordTypeId() : null;
    }

    private class QuoteData {
        Boolean exists = false;
        Decimal amount;
        Date    closeDate;
    }

    /**
     * Latest Approved quote for the Opportunity.
     * EDV  <- Line_Item_Grand_Total__c
     * ECD  <- ExpirationDate
     */
    private static QuoteData getApprovedQuote(Id opportunityId) {
        QuoteData qd = new QuoteData();
        try {
            String approved = QUOTE_APPROVED;
            String soql =
                'SELECT ' + QUOTE_AMOUNT_FIELD + ', ' + QUOTE_CLOSE_FIELD +
                ' FROM '  + QUOTE_OBJECT +
                ' WHERE ' + QUOTE_OPP_FIELD    + ' = :opportunityId' +
                ' AND '   + QUOTE_STATUS_FIELD + ' = :approved' +
                ' ORDER BY LastModifiedDate DESC LIMIT 1';
            List<SObject> rows = Database.query(soql);
            if (!rows.isEmpty()) {
                qd.exists    = true;
                qd.amount    = (Decimal) rows[0].get(QUOTE_AMOUNT_FIELD);
                qd.closeDate = (Date)    rows[0].get(QUOTE_CLOSE_FIELD);
            }
        } catch (Exception e) {
            qd.exists = false;
        }
        return qd;
    }

    private static AuraHandledException handled(String msg) {
        AuraHandledException e = new AuraHandledException(msg);
        e.setMessage(msg);
        return e;
    }
}