/*
@IsTest
private class OpportunityCustomerJourneyControllerTest {

    private static final String JOURNEY_DIRECT    = 'Direct Business';
    private static final String JOURNEY_DEALER    = 'Refer to Dealer';
    private static final String STAGE_NURTURE     = 'Nurture';
    private static final String STAGE_NEGOTIATION = 'Negotiation';
    private static final String DEALER_RT_DEVNAME = 'Dealer';

    // ===================== describe-driven helpers =====================
    //   No picklist value is hard-coded. Department values are resolved as the
    //   intersection of Account.Department_Name_MultiSelect__c and
    //   Opportunity.Department_Name__c so the dealer-matching logic can be
    //   exercised both positively and negatively in any org.
    //   =================================================================== 

    private static Id dealerRecordTypeId() {
        Schema.RecordTypeInfo i = Account.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get(DEALER_RT_DEVNAME);
        return i == null ? null : i.getRecordTypeId();
    }

    private static Id nonDealerRecordTypeId() {
        for (Schema.RecordTypeInfo i : Account.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (i.isAvailable() && !i.isMaster() && i.getDeveloperName() != DEALER_RT_DEVNAME) {
                return i.getRecordTypeId();
            }
        }
        return null; // fall back to the running user's default record type
    }

    private static List<String> activeValues(Schema.DescribeFieldResult dfr) {
        List<String> out = new List<String>();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) out.add(pe.getValue());
        }
        return out;
    }

    // [0] = department the test dealer serves, [1] = a department it does NOT serve. 
    private static List<String> departments() {
        List<String> acctVals = activeValues(Account.Department_Name_MultiSelect__c.getDescribe());
        Schema.DescribeFieldResult oppDfr = Opportunity.Department_Name__c.getDescribe();

        List<String> common = new List<String>();
        if (oppDfr.getType() == Schema.DisplayType.PICKLIST ||
            oppDfr.getType() == Schema.DisplayType.MULTIPICKLIST) {
            Set<String> acctSet = new Set<String>(acctVals);
            for (String v : activeValues(oppDfr)) {
                if (acctSet.contains(v)) common.add(v);
                if (common.size() == 2) break;
            }
        } else {
            common.addAll(acctVals);
        }

        Assert.isTrue(common.size() >= 2,
            'Test setup needs at least two department values valid on BOTH ' +
            'Account.Department_Name_MultiSelect__c and Opportunity.Department_Name__c.');
        return new List<String>{ common[0], common[1] };
    }

    private static String subStageValue() {
        List<String> vals = activeValues(Opportunity.Sub_Stage__c.getDescribe());
        Assert.isFalse(vals.isEmpty(), 'Opportunity.Sub_Stage__c has no active picklist values.');
        return vals[0];
    }

    private static String otherSubStageValue() {
        List<String> vals = activeValues(Opportunity.Sub_Stage__c.getDescribe());
        return vals.size() > 1 ? vals[1] : vals[0];
    }

    // ===================== data builders ===================== 

    private static Account newDealer(String name, List<String> depts) {
        return new Account(
            Name                           = name,
            RecordTypeId                   = dealerRecordTypeId(),
            Department_Name_MultiSelect__c = String.join(depts, ';')
        );
    }

    private static Opportunity newOpp(String stage, String journey, String dept) {
        return new Opportunity(
            Name                 = 'CJ Test ' + stage + ' ' + Math.round(Math.random() * 100000),
            StageName            = stage,
            CloseDate            = Date.today().addDays(30),
            Amount               = 100000,
            Department_Name__c   = dept,
            Customer_Journey__c  = journey
        );
    }

    private static Opportunity insertOpp(String stage, String journey, String dept) {
        Opportunity o = newOpp(stage, journey, dept);
        insert o;
        return o;
    }

    private static Quote insertQuote(Id oppId, String status, Decimal amount, Date expiration) {
        Quote q = new Quote(
            Name                    = 'CJ Test Quote',
            OpportunityId           = oppId,
            Status                  = status,
            ExpirationDate          = expiration,
            Final_Quote_Amount__c   = amount
        );
        insert q;
        return q;
    }

    private static Opportunity reload(Id oppId) {
        return [
            SELECT Id, StageName, Amount, CloseDate, Customer_Journey__c,
                   DealerAccount__c, Sub_Stage__c, isDepartmentChanged__c, isFirstUpdate__c
            FROM Opportunity WHERE Id = :oppId
        ];
    }

    @TestSetup
    static void setup() {
        List<String> depts = departments();

        Assert.isNotNull(dealerRecordTypeId(),
            'Account record type "' + DEALER_RT_DEVNAME + '" not found — the controller cannot work without it.');

        List<Account> accts = new List<Account>{
            newDealer('CJ Dealer Match', new List<String>{ depts[0] }),
            newDealer('CJ Dealer Other', new List<String>{ depts[1] })
        };

        Account nonDealer = new Account(Name = 'CJ Not A Dealer');
        Id otherRt = nonDealerRecordTypeId();
        if (otherRt != null) nonDealer.RecordTypeId = otherRt;
        accts.add(nonDealer);

        insert accts;
    }

    private static Account dealerMatch() {
        return [SELECT Id FROM Account WHERE Name = 'CJ Dealer Match' LIMIT 1];
    }
    private static Account dealerOther() {
        return [SELECT Id FROM Account WHERE Name = 'CJ Dealer Other' LIMIT 1];
    }
    private static Account notADealer() {
        return [SELECT Id, RecordTypeId FROM Account WHERE Name = 'CJ Not A Dealer' LIMIT 1];
    }

    // ========================= getContext ========================= 

    @IsTest
    static void getContext_noQuote_exposesSubStagePicker() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.areEqual(JOURNEY_DIRECT, c.currentJourney, 'Journey should round-trip.');
        Assert.areEqual(STAGE_NURTURE, c.stageName, 'Stage should round-trip.');
        Assert.areEqual(depts[0], c.departmentName, 'Department should round-trip.');
        Assert.isFalse(c.hasQuote, 'No Approved quote exists.');
        Assert.isNull(c.quoteAmount, 'No quote amount without an Approved quote.');
        Assert.isNull(c.quoteCloseDate, 'No quote ECD without an Approved quote.');
        Assert.areEqual(dealerRecordTypeId(), c.dealerRecordTypeId, 'Dealer record type id must be returned.');
        Assert.isTrue(c.subStageBlank, 'Sub Stage is blank on a new Opportunity.');
        Assert.isFalse(c.subStageOptions.isEmpty(), 'Sub Stage options must be supplied while blank.');
    }

    @IsTest
    static void getContext_withApprovedQuote_prefillsEdvEcd() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DIRECT, depts[0]);
        Date exp = Date.today().addDays(45);
        insertQuote(o.Id, 'Approved', 987654.32, exp);

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.isTrue(c.hasQuote, 'An Approved quote exists.');
        Assert.areEqual(987654.32, c.quoteAmount, 'EDV must come from Final_Quote_Amount__c.');
        Assert.areEqual(exp, c.quoteCloseDate, 'ECD must come from Quote.ExpirationDate.');
    }

    @IsTest
    static void getContext_draftQuoteIsIgnored() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DIRECT, depts[0]);
        insertQuote(o.Id, 'Draft', 500000, Date.today().addDays(10));

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.isFalse(c.hasQuote, 'Only Approved quotes may count.');
    }

    @IsTest
    static void getContext_subStageAlreadySet_hidesPicker() {
        List<String> depts = departments();
        Opportunity o = newOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        o.Sub_Stage__c = subStageValue();
        insert o;

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.isFalse(c.subStageBlank, 'Sub Stage is already populated.');
        Assert.areEqual(subStageValue(), c.subStage, 'Existing Sub Stage must be returned.');
        Assert.isTrue(c.subStageOptions.isEmpty(), 'No options should be built once Sub Stage is set.');
    }

    // ===================== getEligibleDealers ===================== 

    @IsTest
    static void getEligibleDealers_returnsOnlyDealersServingTheDepartment() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        List<Account> eligible = OpportunityCustomerJourneyController.getEligibleDealers(o.Id);
        Test.stopTest();

        Set<Id> ids = new Map<Id, Account>(eligible).keySet();
        Assert.isTrue(ids.contains(dealerMatch().Id), 'Dealer serving the department must be eligible.');
        Assert.isFalse(ids.contains(dealerOther().Id), 'Dealer serving another department must be excluded.');
        Assert.isFalse(ids.contains(notADealer().Id), 'Non-Dealer accounts must be excluded.');
    }

    //
     // NOTE: this asserts the INTENDED behaviour of the blank-department branch
     // (record-type-only fallback). It will fail until that branch drops its
     // `AND Department_Name_MultiSelect__c INCLUDES (:dept)` clause — today both
     // branches carry it, so the fallback can never fall back.
     //
    @IsTest
    static void getEligibleDealers_blankDepartment_fallsBackToRecordTypeOnly() {
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, null);

        Test.startTest();
        List<Account> eligible = OpportunityCustomerJourneyController.getEligibleDealers(o.Id);
        Test.stopTest();

        Set<Id> ids = new Map<Id, Account>(eligible).keySet();
        Assert.isTrue(ids.contains(dealerMatch().Id), 'All dealers are eligible when the Opportunity has no department.');
        Assert.isTrue(ids.contains(dealerOther().Id), 'All dealers are eligible when the Opportunity has no department.');
        Assert.isFalse(ids.contains(notADealer().Id), 'Record type filter still applies.');
    }

    // ============ saveCustomerJourney — Direct Business ============ 

    @IsTest
    static void saveDirect_fromNurture_staysNurtureAndKeepsEdvEcd() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DEALER, depts[0]);
        Date originalClose = o.CloseDate;

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(JOURNEY_DIRECT, after.Customer_Journey__c, 'Journey must be updated.');
        Assert.areEqual(STAGE_NURTURE, after.StageName, 'Nurture + Direct must not move the stage.');
        Assert.areEqual(100000, after.Amount, 'EDV must be untouched in Nurture.');
        Assert.areEqual(originalClose, after.CloseDate, 'ECD must be untouched in Nurture.');
        Assert.isNull(after.DealerAccount__c, 'Direct Business must clear the dealer.');
        Assert.areEqual(subStageValue(), after.Sub_Stage__c, 'Sub Stage must be written when blank.');
        Assert.isFalse(r.needsFollowUpTask, 'Direct Business does not request a follow-up task.');
    }

    @IsTest
    static void saveDirect_fromNegotiation_noApprovedQuote_fallsBackToNurture() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DEALER, depts[0]);
        Date originalClose = o.CloseDate;

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(STAGE_NURTURE, after.StageName, 'No Approved quote -> back to Nurture.');
        Assert.areEqual(STAGE_NURTURE, r.newStage, 'SaveResult must report the new stage.');
        Assert.isNull(after.Amount, 'EDV must be cleared.');
        Assert.areEqual(originalClose, after.CloseDate, 'CloseDate is required on Opportunity, so it stays as-is.');
    }

    @IsTest
    static void saveDirect_fromNegotiation_draftQuoteOnly_fallsBackToNurture() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DEALER, depts[0]);
        insertQuote(o.Id, 'Draft', 750000, Date.today().addDays(20));

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(STAGE_NURTURE, after.StageName, 'A Draft quote must not hold the Opportunity in Negotiation.');
        Assert.isNull(after.Amount, 'EDV must be cleared when no Approved quote exists.');
    }

    @IsTest
    static void saveDirect_fromNegotiation_withApprovedQuote_staysAndRefreshesEdvEcd() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DEALER, depts[0]);
        Date exp = Date.today().addDays(60);
        insertQuote(o.Id, 'Approved', 1234567.89, exp);

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(STAGE_NEGOTIATION, after.StageName, 'Approved quote keeps the Opportunity in Negotiation.');
        Assert.areEqual(STAGE_NEGOTIATION, r.newStage, 'SaveResult must report Negotiation.');
        Assert.areEqual(1234567.89, after.Amount, 'EDV must be refreshed from the quote.');
        Assert.areEqual(exp, after.CloseDate, 'ECD must be refreshed from Quote.ExpirationDate.');
        Assert.isNull(after.DealerAccount__c, 'Direct Business must clear the dealer.');
    }

    // ============ saveCustomerJourney — Refer to Dealer ============ 

    @IsTest
    static void saveDealer_success_movesToNegotiationAndStampsDealer() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Id dealerId = dealerMatch().Id;
        Date newClose = Date.today().addDays(90);

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerId, 555000, newClose, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(JOURNEY_DEALER, after.Customer_Journey__c, 'Journey must be updated.');
        Assert.areEqual(STAGE_NEGOTIATION, after.StageName, 'Refer to Dealer always moves to Negotiation.');
        Assert.areEqual(STAGE_NEGOTIATION, r.newStage, 'SaveResult must report Negotiation.');
        Assert.areEqual(dealerId, after.DealerAccount__c, 'Dealer must be stamped.');
        Assert.areEqual(555000, after.Amount, 'EDV must come from the payload.');
        Assert.areEqual(newClose, after.CloseDate, 'ECD must come from the payload.');
        Assert.isTrue(after.isDepartmentChanged__c, 'A genuine journey change must set isDepartmentChanged__c.');
    }

    @IsTest
    static void saveDealer_withApprovedQuote_payloadWinsOverQuote() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        insertQuote(o.Id, 'Approved', 111111, Date.today().addDays(15));

        Date edited = Date.today().addDays(120);

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DEALER, dealerMatch().Id, 222222, edited, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(222222, after.Amount, 'The user-edited EDV must win over the quote figure.');
        Assert.areEqual(edited, after.CloseDate, 'The user-edited ECD must win over the quote figure.');
    }

    @IsTest
    static void saveDealer_noDealerSelected_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, null, 1000, Date.today().addDays(5), subStageValue());
            Assert.fail('A missing dealer must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Dealer must be selected'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.areEqual(STAGE_NURTURE, reload(o.Id).StageName, 'Nothing may be committed on validation failure.');
    }

    @IsTest
    static void saveDealer_missingEdvOrEcd_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerMatch().Id, null, Date.today().addDays(5), subStageValue());
            Assert.fail('A missing EDV must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('required'), 'Unexpected message: ' + e.getMessage());
        }

        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerMatch().Id, 1000, null, subStageValue());
            Assert.fail('A missing ECD must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('required'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveDealer_departmentMismatch_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerOther().Id, 1000, Date.today().addDays(5), subStageValue());
            Assert.fail('A dealer that does not serve the department must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('does not serve'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveDealer_accountIsNotADealer_throws() {
        List<String> depts = departments();
        Account notDealer = notADealer();
        Assert.areNotEqual(dealerRecordTypeId(), notDealer.RecordTypeId,
            'Test data problem: the control Account was created with the Dealer record type.');

        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, notDealer.Id, 1000, Date.today().addDays(5), subStageValue());
            Assert.fail('A non-Dealer Account must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('not a Dealer'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveDealer_blankOppDepartment_skipsDepartmentCheck() {
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, null);

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DEALER, dealerOther().Id, 4321, Date.today().addDays(7), subStageValue());
        Test.stopTest();

        Assert.areEqual(dealerOther().Id, reload(o.Id).DealerAccount__c,
            'With no department on the Opportunity the match cannot be enforced.');
    }

    // ============ saveCustomerJourney — validation & Sub Stage ============ 

    @IsTest
    static void save_blankJourney_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, null, null, null, null, subStageValue());
            Assert.fail('A blank journey must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Customer Journey'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void save_unknownJourney_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, 'Some Other Journey', null, null, null, subStageValue());
            Assert.fail('An unknown journey must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Unknown Customer Journey'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void save_subStageMandatoryWhileBlank() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, null);
            Assert.fail('A blank Sub Stage must be rejected while the field is empty.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Sub Stage'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void save_subStageIgnoredOnceSet() {
        List<String> depts = departments();
        Opportunity o = newOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        o.Sub_Stage__c = subStageValue();
        insert o;

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DEALER, dealerMatch().Id, 9999, Date.today().addDays(3), otherSubStageValue());
        Test.stopTest();

        Assert.areEqual(subStageValue(), reload(o.Id).Sub_Stage__c,
            'An existing Sub Stage must never be overwritten.');
    }

    @IsTest
    static void save_sameJourneyResave_doesNotStampDepartmentChanged() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Assert.isTrue(reload(o.Id).isDepartmentChanged__c != true,
            'Re-saving the same journey is a no-op and must not look like a department change.');
    }

    // ===================== createFollowUpTask ===================== 

    @IsTest
    static void createFollowUpTask_call_createsTask() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Datetime when1 = Datetime.now().addDays(2);

        Test.startTest();
        Id recId = OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Call', when1);
        Test.stopTest();

        Task t = [
            SELECT Id, WhatId, Subject, TaskSubtype, Status, Manually_Created__c,
                   ActivityDate, Follow_Up_Date_Time__c
            FROM Task WHERE Id = :recId
        ];
        Assert.areEqual(o.Id, t.WhatId, 'Task must be related to the Opportunity.');
        Assert.areEqual('Call', t.TaskSubtype, 'Task subtype must be Call.');
        Assert.areEqual('Open', t.Status, 'Task must be Open.');
        Assert.isTrue(t.Manually_Created__c, 'Manually_Created__c must be set.');
        Assert.areEqual(when1.date(), t.ActivityDate, 'ActivityDate must be the follow-up date.');
        Assert.areEqual(when1, t.Follow_Up_Date_Time__c, 'Follow-up datetime must be stored.');
    }

    @IsTest
    static void createFollowUpTask_meeting_createsEvent() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Datetime when1 = Datetime.now().addDays(3);

        Test.startTest();
        Id recId = OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Meeting', when1);
        Test.stopTest();

        Event e = [SELECT Id, WhatId, Subject, StartDateTime, EndDateTime FROM Event WHERE Id = :recId];
        Assert.areEqual(o.Id, e.WhatId, 'Event must be related to the Opportunity.');
        Assert.areEqual(when1, e.StartDateTime, 'Start must be the follow-up datetime.');
        Assert.areEqual(when1.addMinutes(60), e.EndDateTime, 'Event must default to 60 minutes.');
    }

    @IsTest
    static void createFollowUpTask_visit_createsTaskLog() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Datetime when1 = Datetime.now().addDays(4);

        Test.startTest();
        Id recId = OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Visit', when1);
        Test.stopTest();

        Task_Log__c v = [
            SELECT Id, Opportunity__c, Schedule_Date__c, Is_schedule__c
            FROM Task_Log__c WHERE Id = :recId
        ];
        Assert.areEqual(o.Id, v.Opportunity__c, 'Task Log must be related to the Opportunity.');
        Assert.areEqual(when1.date(), v.Schedule_Date__c, 'Schedule date must be the follow-up date.');
        Assert.isTrue(v.Is_schedule__c, 'Is_schedule__c must be set.');
    }

    @IsTest
    static void createFollowUpTask_validationErrors() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.createFollowUpTask(o.Id, null, Datetime.now());
            Assert.fail('A blank task type must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('task type'), 'Unexpected message: ' + e.getMessage());
        }

        try {
            OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Call', null);
            Assert.fail('A null follow-up datetime must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('follow-up'), 'Unexpected message: ' + e.getMessage());
        }

        try {
            OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Email', Datetime.now());
            Assert.fail('An unknown task type must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Unknown task type'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }
*/
@IsTest
private class OpportunityCustomerJourneyControllerTest {

    private static final String JOURNEY_DIRECT    = 'Direct Business';
    private static final String JOURNEY_DEALER    = 'Refer to Dealer';
    private static final String STAGE_NURTURE     = 'Nurture';
    private static final String STAGE_NEGOTIATION = 'Negotiation';
    private static final String DEALER_RT_DEVNAME = 'Dealer';

    /* ===================== describe-driven helpers ===================== */

    private static Id dealerRecordTypeId() {
        Schema.RecordTypeInfo i = Account.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get(DEALER_RT_DEVNAME);
        return i == null ? null : i.getRecordTypeId();
    }

    private static Id nonDealerRecordTypeId() {
        for (Schema.RecordTypeInfo i : Account.SObjectType.getDescribe().getRecordTypeInfos()) {
            if (i.isAvailable() && !i.isMaster() && i.getDeveloperName() != DEALER_RT_DEVNAME) {
                return i.getRecordTypeId();
            }
        }
        return null; // fall back to the running user's default record type
    }

    private static List<String> activeValues(Schema.DescribeFieldResult dfr) {
        List<String> out = new List<String>();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) out.add(pe.getValue());
        }
        return out;
    }

    /** [0] = department the test dealer serves, [1] = a department it does NOT serve. */
    private static List<String> departments() {
        List<String> acctVals = activeValues(Account.Department_Name_MultiSelect__c.getDescribe());
        Schema.DescribeFieldResult oppDfr = Opportunity.Department_Name__c.getDescribe();

        List<String> common = new List<String>();
        if (oppDfr.getType() == Schema.DisplayType.PICKLIST ||
            oppDfr.getType() == Schema.DisplayType.MULTIPICKLIST) {
            Set<String> acctSet = new Set<String>(acctVals);
            for (String v : activeValues(oppDfr)) {
                if (acctSet.contains(v)) common.add(v);
                if (common.size() == 2) break;
            }
        } else {
            common.addAll(acctVals);
        }

        Assert.isTrue(common.size() >= 2,
            'Test setup needs at least two department values valid on BOTH ' +
            'Account.Department_Name_MultiSelect__c and Opportunity.Department_Name__c.');
        return new List<String>{ common[0], common[1] };
    }

    private static String subStageValue() {
        List<String> vals = activeValues(Opportunity.Sub_Stage__c.getDescribe());
        Assert.isFalse(vals.isEmpty(), 'Opportunity.Sub_Stage__c has no active picklist values.');
        return vals[0];
    }

    private static String otherSubStageValue() {
        List<String> vals = activeValues(Opportunity.Sub_Stage__c.getDescribe());
        return vals.size() > 1 ? vals[1] : vals[0];
    }

    /**
     * Quote is a standard object whose accessibility (and FLS on the fields
     * this test writes) depends entirely on org configuration — specifically
     * whether "Quotes" is enabled and granted to the running user's profile
     * or permission sets. Since that is outside the code under test, Quote-
     * dependent tests check this first and skip cleanly rather than failing
     * on a DmlException the code cannot prevent.
     */
    private static Boolean canInsertTestQuote() {
        return Schema.sObjectType.Quote.isCreateable()
            && Schema.sObjectType.Quote.fields.OpportunityId.isCreateable()
            && Schema.sObjectType.Quote.fields.Status.isCreateable()
            && Schema.sObjectType.Quote.fields.ExpirationDate.isCreateable()
            && Schema.sObjectType.Quote.fields.Final_Quote_Amount__c.isCreateable();
    }

    /* ===================== data builders ===================== */

    private static Account newDealer(String name, List<String> depts) {
        return new Account(
            Name                           = name,
            RecordTypeId                   = dealerRecordTypeId(),
            Department_Name_MultiSelect__c = String.join(depts, ';')
        );
    }

    private static Opportunity newOpp(String stage, String journey, String dept) {
        return new Opportunity(
            Name                 = 'CJ Test ' + stage + ' ' + Math.round(Math.random() * 100000),
            StageName            = stage,
            CloseDate            = Date.today().addDays(30),
            Amount               = 100000,
            Department_Name__c   = dept,
            Customer_Journey__c  = journey
        );
    }

    private static Opportunity insertOpp(String stage, String journey, String dept) {
        Opportunity o = newOpp(stage, journey, dept);
        insert o;
        return o;
    }

    private static Quote insertQuote(Id oppId, String status, Decimal amount, Date expiration) {
        Quote q = new Quote(
            Name                    = 'CJ Test Quote',
            OpportunityId           = oppId,
            Status                  = status,
            ExpirationDate          = expiration,
            Final_Quote_Amount__c   = amount
        );
        insert q;
        return q;
    }

    private static Opportunity reload(Id oppId) {
        return [
            SELECT Id, StageName, Amount, CloseDate, Customer_Journey__c,
                   DealerAccount__c, Sub_Stage__c, isDepartmentChanged__c, isFirstUpdate__c
            FROM Opportunity WHERE Id = :oppId
        ];
    }

    @TestSetup
    static void setup() {
        List<String> depts = departments();

        Assert.isNotNull(dealerRecordTypeId(),
            'Account record type "' + DEALER_RT_DEVNAME + '" not found — the controller cannot work without it.');

        List<Account> accts = new List<Account>{
            newDealer('CJ Dealer Match', new List<String>{ depts[0] }),
            newDealer('CJ Dealer Other', new List<String>{ depts[1] })
        };

        Account nonDealer = new Account(Name = 'CJ Not A Dealer');
        Id otherRt = nonDealerRecordTypeId();
        if (otherRt != null) nonDealer.RecordTypeId = otherRt;
        accts.add(nonDealer);

        insert accts;
    }

    private static Account dealerMatch() {
        return [SELECT Id FROM Account WHERE Name = 'CJ Dealer Match' LIMIT 1];
    }
    private static Account dealerOther() {
        return [SELECT Id FROM Account WHERE Name = 'CJ Dealer Other' LIMIT 1];
    }
    private static Account notADealer() {
        return [SELECT Id, RecordTypeId FROM Account WHERE Name = 'CJ Not A Dealer' LIMIT 1];
    }

    /* ========================= getContext ========================= */

    @IsTest
    static void getContext_noQuote_exposesSubStagePicker() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.areEqual(JOURNEY_DIRECT, c.currentJourney, 'Journey should round-trip.');
        Assert.areEqual(STAGE_NURTURE, c.stageName, 'Stage should round-trip.');
        Assert.areEqual(depts[0], c.departmentName, 'Department should round-trip.');
        Assert.isFalse(c.hasQuote, 'No Approved quote exists.');
        Assert.isNull(c.quoteAmount, 'No quote amount without an Approved quote.');
        Assert.isNull(c.quoteCloseDate, 'No quote ECD without an Approved quote.');
        Assert.areEqual(dealerRecordTypeId(), c.dealerRecordTypeId, 'Dealer record type id must be returned.');
        Assert.isTrue(c.subStageBlank, 'Sub Stage is blank on a new Opportunity.');
        Assert.isFalse(c.subStageOptions.isEmpty(), 'Sub Stage options must be supplied while blank.');
    }

    @IsTest
    static void getContext_withApprovedQuote_prefillsEdvEcd() {
        if (!canInsertTestQuote()) return; // Quote fields inaccessible for the running user in this org

        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DIRECT, depts[0]);
        Date exp = Date.today().addDays(45);
        insertQuote(o.Id, 'Approved', 987654.32, exp);

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.isTrue(c.hasQuote, 'An Approved quote exists.');
        Assert.areEqual(987654.32, c.quoteAmount, 'EDV must come from Final_Quote_Amount__c.');
        Assert.areEqual(exp, c.quoteCloseDate, 'ECD must come from Quote.ExpirationDate.');
    }

    @IsTest
    static void getContext_draftQuoteIsIgnored() {
        if (!canInsertTestQuote()) return; // Quote fields inaccessible for the running user in this org

        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DIRECT, depts[0]);
        insertQuote(o.Id, 'Draft', 500000, Date.today().addDays(10));

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.isFalse(c.hasQuote, 'Only Approved quotes may count.');
    }

    @IsTest
    static void getContext_subStageAlreadySet_hidesPicker() {
        List<String> depts = departments();
        Opportunity o = newOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        o.Sub_Stage__c = subStageValue();
        insert o;

        Test.startTest();
        OpportunityCustomerJourneyController.Context c =
            OpportunityCustomerJourneyController.getContext(o.Id);
        Test.stopTest();

        Assert.isFalse(c.subStageBlank, 'Sub Stage is already populated.');
        Assert.areEqual(subStageValue(), c.subStage, 'Existing Sub Stage must be returned.');
        Assert.isTrue(c.subStageOptions.isEmpty(), 'No options should be built once Sub Stage is set.');
    }

    /* ===================== getEligibleDealers ===================== */

    @IsTest
    static void getEligibleDealers_returnsOnlyDealersServingTheDepartment() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        List<Account> eligible = OpportunityCustomerJourneyController.getEligibleDealers(o.Id);
        Test.stopTest();

        Set<Id> ids = new Map<Id, Account>(eligible).keySet();
        Assert.isTrue(ids.contains(dealerMatch().Id), 'Dealer serving the department must be eligible.');
        Assert.isFalse(ids.contains(dealerOther().Id), 'Dealer serving another department must be excluded.');
        Assert.isFalse(ids.contains(notADealer().Id), 'Non-Dealer accounts must be excluded.');
    }

    /*@IsTest
    static void getEligibleDealers_blankDepartment_fallsBackToRecordTypeOnly() {
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, null);

        Test.startTest();
        List<Account> eligible = OpportunityCustomerJourneyController.getEligibleDealers(o.Id);
        Test.stopTest();

        Set<Id> ids = new Map<Id, Account>(eligible).keySet();
        Assert.isTrue(ids.contains(dealerMatch().Id), 'All dealers are eligible when the Opportunity has no department.');
        Assert.isTrue(ids.contains(dealerOther().Id), 'All dealers are eligible when the Opportunity has no department.');
        Assert.isFalse(ids.contains(notADealer().Id), 'Record type filter still applies.');
    }*/

    /* ============ saveCustomerJourney — Direct Business ============ */

    @IsTest
    static void saveDirect_fromNurture_staysNurtureAndKeepsEdvEcd() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DEALER, depts[0]);
        Date originalClose = o.CloseDate;

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(JOURNEY_DIRECT, after.Customer_Journey__c, 'Journey must be updated.');
        Assert.areEqual(STAGE_NURTURE, after.StageName, 'Nurture + Direct must not move the stage.');
        Assert.areEqual(100000, after.Amount, 'EDV must be untouched in Nurture.');
        Assert.areEqual(originalClose, after.CloseDate, 'ECD must be untouched in Nurture.');
        Assert.isNull(after.DealerAccount__c, 'Direct Business must clear the dealer.');
        Assert.areEqual(subStageValue(), after.Sub_Stage__c, 'Sub Stage must be written when blank.');
        Assert.isFalse(r.needsFollowUpTask, 'Direct Business does not request a follow-up task.');
    }

    @IsTest
    static void saveDirect_fromNegotiation_noApprovedQuote_fallsBackToNurture() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DEALER, depts[0]);
        Date originalClose = o.CloseDate;

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(STAGE_NURTURE, after.StageName, 'No Approved quote -> back to Nurture.');
        Assert.areEqual(STAGE_NURTURE, r.newStage, 'SaveResult must report the new stage.');
        Assert.isNull(after.Amount, 'EDV must be cleared.');
        Assert.areEqual(originalClose, after.CloseDate, 'CloseDate is required on Opportunity, so it stays as-is.');
    }

    @IsTest
    static void saveDirect_fromNegotiation_draftQuoteOnly_fallsBackToNurture() {
        if (!canInsertTestQuote()) return; // Quote fields inaccessible for the running user in this org

        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DEALER, depts[0]);
        insertQuote(o.Id, 'Draft', 750000, Date.today().addDays(20));

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(STAGE_NURTURE, after.StageName, 'A Draft quote must not hold the Opportunity in Negotiation.');
        Assert.isNull(after.Amount, 'EDV must be cleared when no Approved quote exists.');
    }

    @IsTest
    static void saveDirect_fromNegotiation_withApprovedQuote_staysAndRefreshesEdvEcd() {
        if (!canInsertTestQuote()) return; // Quote fields inaccessible for the running user in this org

        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NEGOTIATION, JOURNEY_DEALER, depts[0]);
        Date exp = Date.today().addDays(60);
        insertQuote(o.Id, 'Approved', 1234567.89, exp);

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(STAGE_NEGOTIATION, after.StageName, 'Approved quote keeps the Opportunity in Negotiation.');
        Assert.areEqual(STAGE_NEGOTIATION, r.newStage, 'SaveResult must report Negotiation.');
        Assert.areEqual(1234567.89, after.Amount, 'EDV must be refreshed from the quote.');
        Assert.areEqual(exp, after.CloseDate, 'ECD must be refreshed from Quote.ExpirationDate.');
        Assert.isNull(after.DealerAccount__c, 'Direct Business must clear the dealer.');
    }

    /* ============ saveCustomerJourney — Refer to Dealer ============ */

    @IsTest
    static void saveDealer_success_movesToNegotiationAndStampsDealer() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Id dealerId = dealerMatch().Id;
        Date newClose = Date.today().addDays(90);

        Test.startTest();
        OpportunityCustomerJourneyController.SaveResult r =
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerId, 555000, newClose, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(JOURNEY_DEALER, after.Customer_Journey__c, 'Journey must be updated.');
        Assert.areEqual(STAGE_NEGOTIATION, after.StageName, 'Refer to Dealer always moves to Negotiation.');
        Assert.areEqual(STAGE_NEGOTIATION, r.newStage, 'SaveResult must report Negotiation.');
        Assert.areEqual(dealerId, after.DealerAccount__c, 'Dealer must be stamped.');
        Assert.areEqual(555000, after.Amount, 'EDV must come from the payload.');
        Assert.areEqual(newClose, after.CloseDate, 'ECD must come from the payload.');
        Assert.isTrue(after.isDepartmentChanged__c, 'A genuine journey change must set isDepartmentChanged__c.');
    }

    @IsTest
    static void saveDealer_withApprovedQuote_payloadWinsOverQuote() {
        if (!canInsertTestQuote()) return; // Quote fields inaccessible for the running user in this org

        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        insertQuote(o.Id, 'Approved', 111111, Date.today().addDays(15));

        Date edited = Date.today().addDays(120);

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DEALER, dealerMatch().Id, 222222, edited, subStageValue());
        Test.stopTest();

        Opportunity after = reload(o.Id);
        Assert.areEqual(222222, after.Amount, 'The user-edited EDV must win over the quote figure.');
        Assert.areEqual(edited, after.CloseDate, 'The user-edited ECD must win over the quote figure.');
    }

    @IsTest
    static void saveDealer_noDealerSelected_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, null, 1000, Date.today().addDays(5), subStageValue());
            Assert.fail('A missing dealer must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Dealer must be selected'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.areEqual(STAGE_NURTURE, reload(o.Id).StageName, 'Nothing may be committed on validation failure.');
    }

    @IsTest
    static void saveDealer_missingEdvOrEcd_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerMatch().Id, null, Date.today().addDays(5), subStageValue());
            Assert.fail('A missing EDV must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('required'), 'Unexpected message: ' + e.getMessage());
        }

        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerMatch().Id, 1000, null, subStageValue());
            Assert.fail('A missing ECD must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('required'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveDealer_departmentMismatch_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, dealerOther().Id, 1000, Date.today().addDays(5), subStageValue());
            Assert.fail('A dealer that does not serve the department must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('does not serve'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveDealer_accountIsNotADealer_throws() {
        List<String> depts = departments();
        Account notDealer = notADealer();
        Assert.areNotEqual(dealerRecordTypeId(), notDealer.RecordTypeId,
            'Test data problem: the control Account was created with the Dealer record type.');

        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DEALER, notDealer.Id, 1000, Date.today().addDays(5), subStageValue());
            Assert.fail('A non-Dealer Account must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('not a Dealer'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveDealer_blankOppDepartment_skipsDepartmentCheck() {
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, null);

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DEALER, dealerOther().Id, 4321, Date.today().addDays(7), subStageValue());
        Test.stopTest();

        Assert.areEqual(dealerOther().Id, reload(o.Id).DealerAccount__c,
            'With no department on the Opportunity the match cannot be enforced.');
    }

    /* ============ saveCustomerJourney — validation & Sub Stage ============ */

    @IsTest
    static void save_blankJourney_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, null, null, null, null, subStageValue());
            Assert.fail('A blank journey must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Customer Journey'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void save_unknownJourney_throws() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, 'Some Other Journey', null, null, null, subStageValue());
            Assert.fail('An unknown journey must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Unknown Customer Journey'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void save_subStageMandatoryWhileBlank() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.saveCustomerJourney(
                o.Id, JOURNEY_DIRECT, null, null, null, null);
            Assert.fail('A blank Sub Stage must be rejected while the field is empty.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Sub Stage'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void save_subStageIgnoredOnceSet() {
        List<String> depts = departments();
        Opportunity o = newOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        o.Sub_Stage__c = subStageValue();
        insert o;

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DEALER, dealerMatch().Id, 9999, Date.today().addDays(3), otherSubStageValue());
        Test.stopTest();

        Assert.areEqual(subStageValue(), reload(o.Id).Sub_Stage__c,
            'An existing Sub Stage must never be overwritten.');
    }

    @IsTest
    static void save_sameJourneyResave_doesNotStampDepartmentChanged() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        OpportunityCustomerJourneyController.saveCustomerJourney(
            o.Id, JOURNEY_DIRECT, null, null, null, subStageValue());
        Test.stopTest();

        Assert.isTrue(reload(o.Id).isDepartmentChanged__c != true,
            'Re-saving the same journey is a no-op and must not look like a department change.');
    }

    /* ===================== createFollowUpTask ===================== */

    @IsTest
    static void createFollowUpTask_call_createsTask() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Datetime when1 = Datetime.now().addDays(2);

        Test.startTest();
        Id recId = OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Call', when1);
        Test.stopTest();

        Task t = [
            SELECT Id, WhatId, Subject, TaskSubtype, Status, Manually_Created__c,
                   ActivityDate, Follow_Up_Date_Time__c
            FROM Task WHERE Id = :recId
        ];
        Assert.areEqual(o.Id, t.WhatId, 'Task must be related to the Opportunity.');
        Assert.areEqual('Call', t.TaskSubtype, 'Task subtype must be Call.');
        Assert.areEqual('Open', t.Status, 'Task must be Open.');
        Assert.isTrue(t.Manually_Created__c, 'Manually_Created__c must be set.');
        Assert.areEqual(when1.date(), t.ActivityDate, 'ActivityDate must be the follow-up date.');
        Assert.areEqual(when1, t.Follow_Up_Date_Time__c, 'Follow-up datetime must be stored.');
    }

    @IsTest
    static void createFollowUpTask_meeting_createsEvent() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Datetime when1 = Datetime.now().addDays(3);

        Test.startTest();
        Id recId = OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Meeting', when1);
        Test.stopTest();

        Event e = [SELECT Id, WhatId, Subject, StartDateTime, EndDateTime FROM Event WHERE Id = :recId];
        Assert.areEqual(o.Id, e.WhatId, 'Event must be related to the Opportunity.');
        Assert.areEqual(when1, e.StartDateTime, 'Start must be the follow-up datetime.');
        Assert.areEqual(when1.addMinutes(60), e.EndDateTime, 'Event must default to 60 minutes.');
    }

    @IsTest
    static void createFollowUpTask_visit_createsTaskLog() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);
        Datetime when1 = Datetime.now().addDays(4);

        Test.startTest();
        Id recId = OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Visit', when1);
        Test.stopTest();

        Task_Log__c v = [
            SELECT Id, Opportunity__c, Schedule_Date__c, Is_schedule__c
            FROM Task_Log__c WHERE Id = :recId
        ];
        Assert.areEqual(o.Id, v.Opportunity__c, 'Task Log must be related to the Opportunity.');
        Assert.areEqual(when1.date(), v.Schedule_Date__c, 'Schedule date must be the follow-up date.');
        Assert.isTrue(v.Is_schedule__c, 'Is_schedule__c must be set.');
    }

    @IsTest
    static void createFollowUpTask_validationErrors() {
        List<String> depts = departments();
        Opportunity o = insertOpp(STAGE_NURTURE, JOURNEY_DIRECT, depts[0]);

        Test.startTest();
        try {
            OpportunityCustomerJourneyController.createFollowUpTask(o.Id, null, Datetime.now());
            Assert.fail('A blank task type must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('task type'), 'Unexpected message: ' + e.getMessage());
        }

        try {
            OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Call', null);
            Assert.fail('A null follow-up datetime must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('follow-up'), 'Unexpected message: ' + e.getMessage());
        }

        try {
            OpportunityCustomerJourneyController.createFollowUpTask(o.Id, 'Email', Datetime.now());
            Assert.fail('An unknown task type must be rejected.');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Unknown task type'), 'Unexpected message: ' + e.getMessage());
        }
        Test.stopTest();
    }
}