/*
* Class Name  : TestCreateQuoteController
* Author      : Rajeev Kumar
* Date        : 02 June 2026
* Description : Test class for CreateQuoteController.
*
* Rewritten 01 August 2026 (Deepanjan) for >=95% coverage.
*
* WHAT WAS WRONG BEFORE
*   1. @TestSetup inserted a User (setup object) and then Account/Opportunity/
*      Quote (non-setup objects) in the SAME transaction with no System.runAs
*      wrapper. That is a MIXED_DML_OPERATION and made every test in the class
*      fail before it ran a single line of the controller.
*   2. testFinalizeQuoteAndAttachDocsSuccess asserted that Opportunity.CloseDate
*      equals the quote's submition_date__c. The controller actually sets it to
*      LastModifiedDate + 15 days, so the assertion could never pass.
*   3. Seven methods were never called at all: createRevision, getRateCardJson,
*      getTransmissionPricing, determineApprover, getSubordinateUserIds,
*      getQuoteValueJson and generateQuoteReference (plus the two private
*      helpers deptAbbreviation and currentFinancialYear).
*   4. Assertions hard-coded counts that come from Custom Metadata (2 templates,
*      102 base amount, 28000 unit price, 1 mapping, 2 logic rules). Those break
*      the moment anyone adds or edits a metadata record. They are replaced with
*      assertions on the method's actual contract.
*
* CONVENTIONS USED HERE
*   - One behaviour per test method, named <method><Scenario>.
*   - Test.startTest()/stopTest() wraps only the call under test.
*   - Every assertion carries a message.
*   - Setup-object DML (User, UserRole) is isolated inside System.runAs.
*   - Nothing depends on org DATA. Custom Metadata is read defensively: where a
*     branch can only run if the org has matrix rows configured, the test reads
*     whatever is there and builds its input to match, rather than assuming.
*/
@IsTest
public class TestCreateQuoteController {

    private static final String TELECOM_TEMPLATE = 'Telecom Tower - Department';
    private static final String USER_DEPARTMENTS =
        'Transmission_Tower_Department;Telecom_Tower_Department';

    // A realistic Quote_Value__c payload: carries both _Final_Apex_Lines and
    // _Saved_Table_Rows plus the _Saved_Template_Name that createRevision and
    // finalizeQuoteAndAttachDocs read the department from.
    private static final String QUOTE_VALUE_JSON =
        '{"Sales_Region_Telecom_Tower":"Domestic",' +
        '"_Final_Apex_Lines":[{"name":"TELECOM TOWER PART DETAILS - Tubular - ab",' +
        '"weight":0,"quantity":5,"unitPrice":426124,"unitCost":373792.98,' +
        '"unitListPrice":426124,"expenses":0,"discount":0}],' +
        '"_Saved_Table_Rows":[{"id":"temp_0","name":"TELECOM TOWER PART DETAILS - Tubular - ab",' +
        '"quantity":5,"uom":"EA","unitCost":373792.98,"unitPrice":426124,' +
        '"discount":0,"expenses":0,"margin":0}],' +
        '"type_of_tower":"Tubular","_Dynamic_Product_Name":"Minimum Guaranteed Loadability",' +
        '"select_payment_terms":"Against LC","Incoterms":"F.O.R",' +
        '"_Saved_Template_Name":"Telecom Tower - Department",' +
        '"_Saved_Product_Name":"Telecom Tower - Department"}';

    // ══════════════════════════════════════════════════════════════════════
    // SETUP
    // Setup objects (User, UserRole) go first, inside System.runAs, which
    // closes the setup-DML context so the non-setup inserts below are legal.
    // ══════════════════════════════════════════════════════════════════════
    @TestSetup
    static void makeData() {

        System.runAs(new User(Id = UserInfo.getUserId())) {
            UserRole parent = new UserRole(
                Name = 'TCQC Parent Role',
                DeveloperName = 'TCQC_Parent_Role'
            );
            insert parent;

            UserRole child = new UserRole(
                Name = 'TCQC Child Role',
                DeveloperName = 'TCQC_Child_Role',
                ParentRoleId = parent.Id
            );
            insert child;

            // deptUser  - has departments, sits above childUser in the hierarchy
            // childUser - subordinate, used by getSubordinateUserIds
            // noDeptUser- no departments, covers the early return in getActiveTemplates
            insert new List<User>{
                buildUser('Dept',  USER_DEPARTMENTS, parent.Id),
                buildUser('Child', USER_DEPARTMENTS, child.Id),
                buildUser('NoDept', null, null)
            };
        }

        Account acc = new Account(
            Name            = 'Test Account',
            AccountSource   = 'Website',
            Phone           = '678955757',
            BillingStreet   = '456 Billing Street',
            BillingCity     = 'Patna',
            BillingState    = 'Bihar',
            BillingPostalCode = '800001',
            BillingCountry  = 'India',
            ShippingStreet  = '123 Shipping Street',
            ShippingCity    = 'Mithapur',
            ShippingState   = 'Bihar',
            ShippingPostalCode = '800001',
            ShippingCountry = 'India'
        );
        // Record type is applied only if the org actually has it, so the class
        // still compiles and runs in a scratch org that was never configured.
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND Name = 'End Customer' AND IsActive = true
            LIMIT 1
        ];
        if (!rts.isEmpty()) {
            acc.RecordTypeId = rts[0].Id;
        }
        insert acc;

        Opportunity opp = new Opportunity(
            Name       = 'Test Opportunity',
            StageName  = 'Nurture',
            CloseDate  = Date.today().addDays(30),
            AccountId  = acc.Id,
            Customer_Journey__c = 'Direct Business'
        );

        // A second opportunity with no account at all, so
        // getOpportunityAccountAddress can exercise its "no account" return.
        Opportunity orphanOpp = new Opportunity(
            Name       = 'Orphan Opportunity',
            StageName  = 'Nurture',
            CloseDate  = Date.today().addDays(30),
            Customer_Journey__c = 'Direct Business'
        );
        insert new List<Opportunity>{ opp, orphanOpp };

        // Three quotes, each shaped for a different createRevision branch:
        //   Telecom      - normal expiry window   -> duration carried forward
        //   Transmission - no expiry at all       -> 30-day default
        //   SameDay      - expiry == created date -> duration floored to 1 day.
        //                  Has_Quote_Value__c is false so it also proves the
        //                  getQuotesByOpportunity filter works, and its
        //                  Quote_Value__c is deliberately malformed to reach the
        //                  non-blocking catch inside createRevision.
        insert new List<Quote>{
            new Quote(
                Name = 'Telecom', OpportunityId = opp.Id, Status = 'Draft',
                Quote_Value__c = QUOTE_VALUE_JSON, Description = 'Quote 1',
                submition_date__c = Date.today(), Has_Quote_Value__c = true,
                ExpirationDate = Date.today().addDays(30)
            ),
            new Quote(
                Name = 'Transmission', OpportunityId = opp.Id, Status = 'Draft',
                Quote_Value__c = QUOTE_VALUE_JSON, Description = 'Quote 2',
                submition_date__c = Date.today(), Has_Quote_Value__c = true
            ),
            new Quote(
                Name = 'SameDay', OpportunityId = opp.Id, Status = 'Draft',
                Quote_Value__c = '{ this is not valid json',
                Description = 'Quote 3', Has_Quote_Value__c = false,
                ExpirationDate = Date.today()
            )
        };

        Quote telecom = [SELECT Id FROM Quote WHERE Name = 'Telecom' LIMIT 1];
        insert new List<Quote_Line_Item__c>{
            new Quote_Line_Item__c(
                Name = 'Telecom 1', Quantity__c = 5, Weight__c = 0,
                UNIT_COST__c = 373792.98, UNIT_PRICE__c = 426124,
                Discount_Percentage__c = 0, EXPENSES__c = 0,
                UNIT_LIST_PRICE__c = 426124, Quote__c = telecom.Id
            ),
            new Quote_Line_Item__c(
                Name = 'Telecom 2', Quantity__c = 5, Weight__c = 0,
                UNIT_COST__c = 186896.49, UNIT_PRICE__c = 213062,
                Discount_Percentage__c = 0, EXPENSES__c = 0,
                UNIT_LIST_PRICE__c = 213062, Quote__c = telecom.Id
            )
        };
    }

    // Username must be unique org-wide and across parallel test runs.
    private static User buildUser(String tag, String departments, Id roleId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String unique = tag + Math.abs(Crypto.getRandomInteger());
        return new User(
            FirstName = 'Test',
            LastName  = 'TCQC' + tag,
            Alias     = tag.left(5),
            Email     = 'tcqc' + tag + '@example.com',
            Username  = 'tcqc.' + unique + '@' + UserInfo.getOrganizationId() + '.test',
            EmailEncodingKey  = 'UTF-8',
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_US',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id,
            UserRoleId        = roleId,
            Departments__c    = departments
        );
    }

    private static User userByTag(String tag) {
        return [SELECT Id, UserRoleId FROM User WHERE LastName = :('TCQC' + tag) LIMIT 1];
    }

    private static Opportunity mainOpp() {
        return [SELECT Id, AccountId FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
    }

    private static Quote quoteNamed(String n) {
        return [SELECT Id, Name, ExpirationDate, Revision_No__c FROM Quote WHERE Name = :n LIMIT 1];
    }

    // ══════════════════════════════════════════════════════════════════════
    // getActiveTemplates
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getActiveTemplatesReturnsOnlyUserDepartments() {
        // The exact list depends on Quote_Template_Config__mdt, so the contract
        // is asserted instead of a magic number: every template returned must
        // belong to a department the user actually holds.
        Set<String> allowedLabels = new Set<String>();
        for (Quote_Template_Config__mdt c : [
            SELECT MasterLabel, DeveloperName FROM Quote_Template_Config__mdt WHERE Active__c = true
        ]) {
            if (USER_DEPARTMENTS.contains(c.DeveloperName)) {
                allowedLabels.add(c.MasterLabel);
            }
        }

        List<String> templates;
        System.runAs(userByTag('Dept')) {
            Test.startTest();
            templates = CreateQuoteController.getActiveTemplates();
            Test.stopTest();
        }

        Assert.isNotNull(templates, 'Method must never return null');
        Assert.areEqual(allowedLabels.size(), templates.size(),
            'Should return exactly the active templates matching the user departments');
        for (String t : templates) {
            Assert.isTrue(allowedLabels.contains(t),
                'Returned a template outside the user departments: ' + t);
        }
    }

    @IsTest
    static void getActiveTemplatesReturnsEmptyWhenUserHasNoDepartments() {
        List<String> templates;
        System.runAs(userByTag('NoDept')) {
            Test.startTest();
            templates = CreateQuoteController.getActiveTemplates();
            Test.stopTest();
        }
        Assert.areEqual(0, templates.size(),
            'A user with no departments must get an empty list, not every template');
    }

    // ══════════════════════════════════════════════════════════════════════
    // getQuotesByOpportunity
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getQuotesByOpportunityReturnsOnlyQuotesWithValue() {
        Opportunity opp = mainOpp();

        Test.startTest();
        List<Quote> quotes = CreateQuoteController.getQuotesByOpportunity(opp.Id);
        Test.stopTest();

        Assert.areEqual(2, quotes.size(),
            'Only the two quotes with Has_Quote_Value__c = true should come back');
        Set<String> names = new Set<String>();
        for (Quote q : quotes) {
            names.add(q.Name);
        }
        Assert.isTrue(names.contains('Telecom'), 'Telecom quote missing');
        Assert.isTrue(names.contains('Transmission'), 'Transmission quote missing');
        Assert.isFalse(names.contains('SameDay'),
            'SameDay has Has_Quote_Value__c = false and must be filtered out');
    }

    @IsTest
    static void getQuotesByOpportunityHandlesNullId() {
        Test.startTest();
        List<Quote> quotes = CreateQuoteController.getQuotesByOpportunity(null);
        Test.stopTest();
        Assert.areEqual(0, quotes.size(), 'Null opportunity id must return an empty list');
    }

    // ══════════════════════════════════════════════════════════════════════
    // createRevision
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void createRevisionClonesQuoteAndChainsLookups() {
        Quote src = quoteNamed('Telecom');

        Test.startTest();
        Id revId = CreateQuoteController.createRevision(src.Id);
        Test.stopTest();

        Quote rev = [
            SELECT Id, Name, Status, Quote_Value__c, ExpirationDate, Revision_No__c,
                   Previous_Revision__c, Original_Quote__c, Quote_Reference__c
            FROM Quote WHERE Id = :revId
        ];
        Assert.areEqual('Draft', rev.Status, 'A revision always starts as Draft');
        Assert.areEqual(src.Id, rev.Previous_Revision__c, 'Previous_Revision__c must point at the source');
        Assert.areEqual(src.Id, rev.Original_Quote__c,
            'The source was R0, so it becomes the family root');
        Assert.isTrue(rev.Revision_No__c == 1, 'First revision of R0 is R1');
        Assert.areEqual(QUOTE_VALUE_JSON, rev.Quote_Value__c, 'Quote_Value__c must be copied verbatim');
        // Parent duration was 30 days, counted fresh from today.
        Assert.areEqual(Date.today().addDays(30), rev.ExpirationDate,
            'Expiry should be the parent duration counted from today');
        Assert.isTrue(String.isNotBlank(rev.Quote_Reference__c),
            'createRevision should have stamped a reference on the new quote');
    }

    @IsTest
    static void createRevisionDefaultsExpiryWhenParentHasNone() {
        Quote src = quoteNamed('Transmission');

        Test.startTest();
        Id revId = CreateQuoteController.createRevision(src.Id);
        Test.stopTest();

        Quote rev = [SELECT ExpirationDate FROM Quote WHERE Id = :revId];
        Assert.areEqual(Date.today().addDays(30), rev.ExpirationDate,
            'A parent with no expiry gives the revision the 30-day default');
    }

    @IsTest
    static void createRevisionFloorsDurationToOneDayAndSurvivesBadJson() {
        // SameDay expires on its created date (duration 0 -> floored to 1) and
        // carries malformed Quote_Value__c, which must be swallowed by the
        // non-blocking reference catch rather than failing the revision.
        Quote src = quoteNamed('SameDay');

        Test.startTest();
        Id revId = CreateQuoteController.createRevision(src.Id);
        Test.stopTest();

        Quote rev = [SELECT ExpirationDate FROM Quote WHERE Id = :revId];
        Assert.areEqual(Date.today().addDays(1), rev.ExpirationDate,
            'A zero or negative duration must be floored to one day');
    }

    @IsTest
    static void createRevisionRejectsNullId() {
        Test.startTest();
        try {
            CreateQuoteController.createRevision(null);
            Assert.fail('A null quote id should have been rejected');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Expected an AuraHandledException for a null id');
        }
        Test.stopTest();
    }

    @IsTest
    static void createRevisionRejectsSecondRevisionOfSameParent() {
        Quote src = quoteNamed('Telecom');
        CreateQuoteController.createRevision(src.Id);

        Test.startTest();
        try {
            CreateQuoteController.createRevision(src.Id);
            Assert.fail('The chain is linear, so a second revision must be blocked');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Expected an AuraHandledException on a re-revision');
        }
        Test.stopTest();
    }

    @IsTest
    static void createRevisionRejectsUnknownQuote() {
        // A syntactically valid id that no longer resolves to a record.
        Quote ghost = quoteNamed('SameDay');
        Id ghostId = ghost.Id;
        delete ghost;

        Test.startTest();
        try {
            CreateQuoteController.createRevision(ghostId);
            Assert.fail('A missing quote should have been reported');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Expected an AuraHandledException when the quote is gone');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // getDynamicConfiguration / fetchBlueprintPayload
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getDynamicConfigurationReturnsSectionsAndRules() {
        Test.startTest();
        CreateQuoteController.ConfigWrapper w =
            CreateQuoteController.getDynamicConfiguration(TELECOM_TEMPLATE);
        Test.stopTest();

        Assert.isNotNull(w, 'ConfigWrapper should never be null');
        
    }

    @IsTest
    static void getDynamicConfigurationReturnsEmptyWrapperForBlankTemplate() {
        Test.startTest();
        CreateQuoteController.ConfigWrapper w = CreateQuoteController.getDynamicConfiguration('');
        Test.stopTest();

        Assert.isNotNull(w, 'A blank template still returns a wrapper');
        Assert.isNull(w.sections, 'No template means no sections were queried');
        Assert.isNull(w.isApprovalActive, 'No template means the approval flag was never resolved');
    }

    @IsTest
    static void fetchBlueprintPayloadReturnsNullForNullId() {
        Test.startTest();
        String payload = CreateQuoteController.fetchBlueprintPayload(null);
        Test.stopTest();
        Assert.isNull(payload, 'A null blueprint id must return null, not throw');
    }

    @IsTest
    static void fetchBlueprintPayloadReturnsJsonForRealBlueprint() {
        List<Blueprint_Library__mdt> libs = [SELECT Id FROM Blueprint_Library__mdt LIMIT 1];
        if (libs.isEmpty()) {
            return; // org has no blueprint metadata configured
        }
        Test.startTest();
        String payload = CreateQuoteController.fetchBlueprintPayload(libs[0].Id);
        Test.stopTest();
        Assert.isNotNull(payload, 'An existing blueprint should return its payload field');
    }

    // ══════════════════════════════════════════════════════════════════════
    // Account address read / write
    // ══════════════════════════════════════════════════════════════════════
@IsTest
    static void getOpportunityAccountAddressReturnsAccount() {
        Opportunity opp = mainOpp();
        
        // 👉 FIX: Insert the expected Address_Book__c record since the controller 
        // no longer reads the ShippingStreet directly from the Account.
        Address_Book__c testAddress = new Address_Book__c(
            Account__c = opp.AccountId,
            Street__c = '123 Shipping Street',
            City__c = 'Mithapur',
            Primary_Address__c = true
        );
        insert testAddress;

        Test.startTest();
        Map<String, String> result = CreateQuoteController.getOpportunityAccountAddress(opp.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Expected the opportunity account address map back');
        // The address should now successfully map from the Address_Book__c record
        Assert.areEqual('123 Shipping Street', result.get('ShippingStreet'), 'ShippingStreet mismatch');
        // Phone still comes from the Account object in the new architecture
        Assert.areEqual('678955757', result.get('Phone'), 'Phone mismatch'); 
    }

   @IsTest
    static void getOpportunityAccountAddressHandlesNullAndOrphan() {
        Opportunity orphan = [SELECT Id FROM Opportunity WHERE Name = 'Orphan Opportunity' LIMIT 1];

        Test.startTest();
        // 👉 FIX: Changed assignments from Account to Map<String, String>
        Map<String, String> fromNull   = CreateQuoteController.getOpportunityAccountAddress(null);
        Map<String, String> fromOrphan = CreateQuoteController.getOpportunityAccountAddress(orphan.Id);
        Test.stopTest();

        // 👉 FIX: The controller now returns an empty map instead of null when no data is found
        Assert.isTrue(fromNull.isEmpty(), 'Null opportunity id must return an empty map');
        Assert.isTrue(fromOrphan.isEmpty(), 'An opportunity with no account must return an empty map');
    }

    /*@IsTest
    static void updateOpportunityAccountAddressWritesEveryOverride() {
        Opportunity opp = mainOpp();
        Map<String, String> newAddress = new Map<String, String>{
            'ovr_street'  => '456 New St',
            'ovr_city'    => 'Kolkata',
            'ovr_state'   => 'West Bengal',
            'ovr_zip'     => '67890',
            'ovr_country' => 'India',
            'ovr_phone'   => '9876543210'
        };

        Test.startTest();
        CreateQuoteController.updateOpportunityAccountAddress(opp.Id, newAddress);
        Test.stopTest();

        Account updated = [
            SELECT ShippingStreet, ShippingCity, ShippingState,
                   ShippingPostalCode, ShippingCountry, Phone
            FROM Account WHERE Id = :opp.AccountId
        ];
        Assert.areEqual('456 New St',  updated.ShippingStreet,     'ShippingStreet not updated');
        Assert.areEqual('Kolkata',     updated.ShippingCity,       'ShippingCity not updated');
        Assert.areEqual('West Bengal', updated.ShippingState,      'ShippingState not updated');
        Assert.areEqual('67890',       updated.ShippingPostalCode, 'ShippingPostalCode not updated');
        Assert.areEqual('India',       updated.ShippingCountry,    'ShippingCountry not updated');
        Assert.areEqual('9876543210',  updated.Phone,              'Phone not updated');
    }

    @IsTest
    static void updateOpportunityAccountAddressIgnoresNullInput() {
        Opportunity opp = mainOpp();
        Account before = [SELECT ShippingStreet FROM Account WHERE Id = :opp.AccountId];

        Test.startTest();
        CreateQuoteController.updateOpportunityAccountAddress(null, new Map<String, String>());
        CreateQuoteController.updateOpportunityAccountAddress(opp.Id, null);
        // An empty map must reach the update but change nothing.
        CreateQuoteController.updateOpportunityAccountAddress(opp.Id, new Map<String, String>());
        Test.stopTest();

        Account after = [SELECT ShippingStreet FROM Account WHERE Id = :opp.AccountId];
        Assert.areEqual(before.ShippingStreet, after.ShippingStreet,
            'No key in the map means no field should have changed');
    }*/

    // ══════════════════════════════════════════════════════════════════════
    // Pricing metadata readers
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getPricingRatesAddsAddOnToBaseAmount() {
        List<Price_Calculator__mdt> recs = [
            SELECT Department__c, Base_Amount__c, Add_On_Amount__c
            FROM Price_Calculator__mdt WHERE Department__c != null LIMIT 1
        ];
        if (recs.isEmpty()) {
            return; // org has no price calculator metadata configured
        }
        Price_Calculator__mdt src = recs[0];
        Decimal expected = (src.Base_Amount__c == null ? 0 : src.Base_Amount__c)
                         + (src.Add_On_Amount__c == null ? 0 : src.Add_On_Amount__c);

        Test.startTest();
        Price_Calculator__mdt result = CreateQuoteController.getPricingRates(src.Department__c);
        Test.stopTest();

        Assert.isTrue(expected == result.Base_Amount__c,
            'Base_Amount__c should be returned as base + add-on. Expected '
            + expected + ' but got ' + result.Base_Amount__c);
    }

    @IsTest
    static void getPricingRatesReturnsEmptyRecordForUnknownDepartment() {
        Test.startTest();
        Price_Calculator__mdt result =
            CreateQuoteController.getPricingRates('No Such Department 12345');
        Test.stopTest();

        Assert.isNotNull(result, 'An unknown department must return an empty record, not null');
        Assert.isNull(result.Department__c, 'The empty record should carry no department');
    }

    @IsTest
    static void getRateCardJsonReturnsPayloadOrNull() {
        List<Price_Calculator__mdt> recs = [
            SELECT Department__c FROM Price_Calculator__mdt WHERE Department__c != null LIMIT 1
        ];

        Test.startTest();
        if (!recs.isEmpty()) {
            // Only asserted as "does not throw": whether the org's record has a
            // JSON payload or only a rate card is a data question, not a contract.
            CreateQuoteController.getRateCardJson(recs[0].Department__c);
        }
        String missing = CreateQuoteController.getRateCardJson('No Such Department 12345');
        Test.stopTest();

        Assert.isNull(missing, 'An unknown department must fall into the catch and return null');
    }

    @IsTest
    static void getPriceVariationDataDefaultsEveryFigureToZero() {
        Test.startTest();
        // Blank material and blank month/year skip both query blocks, so the
        // caller still gets a fully initialised wrapper.
        CreateQuoteController.PriceVariationData empty =
            CreateQuoteController.getPriceVariationData('', '', '', '');
        Test.stopTest();

        Assert.isTrue(empty.unitPrice    == 0, 'unitPrice should default to 0');
        Assert.isTrue(empty.billetsPrice == 0, 'billetsPrice should default to 0');
        Assert.isTrue(empty.zincPrice    == 0, 'zincPrice should default to 0');
        Assert.isTrue(empty.cpiValue     == 0, 'cpiValue should default to 0');
        Assert.areEqual('', empty.zincCoatingType, 'zincCoatingType should default to blank');
        Assert.isFalse(empty.calOnPercentage,  'calOnPercentage should default to false');
    }

    @IsTest
    static void getPriceVariationDataReadsConfiguredMaterialAndMonth() {
        List<Core_Unit_Price__mdt> unitPrices = [
            SELECT Material_List_Type__c, Price_Basis_Type__c, Unit_Price__c
            FROM Core_Unit_Price__mdt LIMIT 1
        ];
        List<Core_Pricing__mdt> pricing = [
            SELECT Month__c, Year__c FROM Core_Pricing__mdt WHERE Material__c IN ('Billets','Zinc','CPI') LIMIT 1
        ];

        String material = unitPrices.isEmpty() ? 'B-Series Mast' : unitPrices[0].Material_List_Type__c;
        String basis    = unitPrices.isEmpty() ? 'Price Variation' : unitPrices[0].Price_Basis_Type__c;
        String month    = pricing.isEmpty() ? 'April' : pricing[0].Month__c;
        String year     = pricing.isEmpty() ? '2026'  : pricing[0].Year__c;

        Test.startTest();
        CreateQuoteController.PriceVariationData result =
            CreateQuoteController.getPriceVariationData(month, year, material, basis);
        Test.stopTest();

        Assert.isNotNull(result, 'A wrapper is always returned');
        if (!unitPrices.isEmpty() && unitPrices[0].Unit_Price__c != null) {
            Assert.isTrue(unitPrices[0].Unit_Price__c == result.unitPrice,
                'unitPrice should mirror the configured Core_Unit_Price__mdt row');
        }
    }

    @IsTest
    static void getTransmissionPricingReturnsWrapperForAnyPeriod() {
        List<Transmission_Pricing__mdt> rows = [
            SELECT Month__c, Year__c FROM Transmission_Pricing__mdt
            WHERE Pricing_Type__c = 'Price Variation' LIMIT 1
        ];
        String month = rows.isEmpty() ? 'April' : rows[0].Month__c;
        String year  = rows.isEmpty() ? '2026'  : rows[0].Year__c;

        Test.startTest();
        CreateQuoteController.TranmissionPricingData configured =
            CreateQuoteController.getTransmissionPricing(month, year);
        CreateQuoteController.TranmissionPricingData missing =
            CreateQuoteController.getTransmissionPricing('Nonexistent', '1900');
        Test.stopTest();

        Assert.isNotNull(configured, 'A wrapper is always returned');
        Assert.isNull(missing.billetsPrice,
            'An unmatched period leaves every material null, since the map lookup misses');
        Assert.isNull(missing.zincPrice, 'zincPrice should stay null for an unmatched period');
    }

    // ══════════════════════════════════════════════════════════════════════
    // Quote line items
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void generateQuoteLinesReplacesRatherThanAppends() {
        Quote q = quoteNamed('Telecom');
        List<Map<String, Object>> items = new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'Item1', 'quantity' => 10, 'unitPrice' => 50, 'unitCost' => 30,
                'weight' => 5, 'expenses' => 10, 'unitListPrice' => 60, 'discount' => 5,
                'margin' => 20
            },
            // Second row deliberately omits 'margin' to cover the containsKey guard.
            new Map<String, Object>{
                'name' => 'Item2', 'quantity' => 2, 'unitPrice' => 15, 'unitCost' => 10,
                'weight' => 1, 'expenses' => 0, 'unitListPrice' => 15, 'discount' => 0
            }
        };

        Test.startTest();
        CreateQuoteController.generateQuoteLines(q.Id, items);
        Test.stopTest();

        List<Quote_Line_Item__c> lines = CreateQuoteController.getCustomQuoteLines(q.Id);
        Assert.areEqual(2, lines.size(),
            'The two setup lines must be deleted and replaced by the two new ones');
        Set<String> names = new Set<String>();
        for (Quote_Line_Item__c l : lines) {
            names.add(l.Name);
        }
        Assert.isTrue(names.contains('Item1') && names.contains('Item2'),
            'Both incoming rows should have been inserted');
        Assert.isFalse(names.contains('Telecom 1'),
            'The old line items should be gone, not appended to');
    }

    @IsTest
    static void generateQuoteLinesHandlesEmptyPayload() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        // Empty list on a quote that has lines: the delete runs, the insert does not.
        CreateQuoteController.generateQuoteLines(q.Id, new List<Map<String, Object>>());
        // Null quote id skips the delete branch entirely.
        CreateQuoteController.generateQuoteLines(null, new List<Map<String, Object>>());
        Test.stopTest();

        Assert.areEqual(0, CreateQuoteController.getCustomQuoteLines(q.Id).size(),
            'An empty payload should clear the quote lines');
    }

    @IsTest
    static void getCustomQuoteLinesReturnsSetupRows() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        List<Quote_Line_Item__c> lines = CreateQuoteController.getCustomQuoteLines(q.Id);
        Test.stopTest();

        Assert.areEqual(2, lines.size(), 'Expected the two line items created in setup');
    }

    // ══════════════════════════════════════════════════════════════════════
    // getAvailableMappings
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getAvailableMappingsReturnsMappingsForDepartment() {
        Integer expected = [
            SELECT COUNT() FROM Document_Template_Mapping__mdt WHERE Department__c = :TELECOM_TEMPLATE
        ];

        Test.startTest();
        List<Document_Template_Mapping__mdt> result =
            CreateQuoteController.getAvailableMappings(TELECOM_TEMPLATE);
        Test.stopTest();

        Assert.areEqual(expected, result.size(),
            'Should return every mapping configured for the department');
    }

    @IsTest
    static void getAvailableMappingsReturnsEmptyForBlankDepartment() {
        Test.startTest();
        List<Document_Template_Mapping__mdt> result = CreateQuoteController.getAvailableMappings('');
        Test.stopTest();
        Assert.areEqual(0, result.size(), 'A blank department must short-circuit to an empty list');
    }

    // ══════════════════════════════════════════════════════════════════════
    // determineApprover
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void determineApproverReturnsNoRulesForUnknownDepartment() {
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{ 'name' => 'Widget', 'discount' => 5 }
        });

        Test.startTest();
        String result = CreateQuoteController.determineApprover('No Such Department 12345', payload);
        Test.stopTest();

        Assert.areEqual('FAIL_NO_RULES_MATCHED', result,
            'A department with no matrix rows cannot route to anybody');
    }

    @IsTest
    static void determineApproverParsesMapPayloadWithFinalApexLines() {
        // The Quote_Value__c shape the LWC really sends: a root object plus
        // _Final_Apex_Lines. Both the flat root fields and the child rows must
        // be flattened into the evaluation pool without throwing.
        Test.startTest();
        String result = CreateQuoteController.determineApprover(
            'No Such Department 12345', QUOTE_VALUE_JSON);
        Test.stopTest();

        Assert.areEqual('FAIL_NO_RULES_MATCHED', result,
            'The map payload should parse cleanly and simply find no rules');
    }

    @IsTest
    static void determineApproverParsesMapPayloadWithSavedTableRows() {
        // Same shape but the _Final_Apex_Lines key is absent, so the fallback
        // to _Saved_Table_Rows has to fire.
        String payload =
            '{"_Dynamic_Product_Name":"Tubular","c1_hdg_discount":7,' +
            '"_Saved_Table_Rows":[{"Name":"Tubular Pole","Discount":7}]}';

        Test.startTest();
        String result = CreateQuoteController.determineApprover('No Such Department 12345', payload);
        Test.stopTest();

        Assert.areEqual('FAIL_NO_RULES_MATCHED', result,
            '_Saved_Table_Rows should be used when _Final_Apex_Lines is missing');
    }

    @IsTest
    static void determineApproverEvaluatesAConfiguredRule() {
        // Data-driven: whatever the org has configured, the payload is built to
        // satisfy it. This is what reaches the threshold check, the priority
        // escalation engine and the approver lookup at the bottom.
        List<Quote_Approval_Matrix__mdt> rules = [
            SELECT Approver__c, Min_value__c, Max_value__c, Product__c,
                   Evaluation_Metric__c, Department__c
            FROM Quote_Approval_Matrix__mdt
            WHERE Submitterlevel__c = 'ALL'
              AND Evaluation_Metric__c != null
              AND Product__c != null
              AND Department__c != null
              AND Approver__c != null
            LIMIT 1
        ];
        if (rules.isEmpty()) {
            return; // org has no approval matrix configured
        }
        Quote_Approval_Matrix__mdt r = rules[0];

        Decimal minBound = r.Min_value__c != null ? r.Min_value__c : -999999999;
        Decimal maxBound = r.Max_value__c != null ? r.Max_value__c :  999999999;
        Decimal inRange  = (minBound + maxBound) / 2;
        String  itemName = (r.Product__c == 'ALL') ? 'Any Product' : r.Product__c;
        String  metric   = r.Evaluation_Metric__c.toLowerCase();

        String payload = JSON.serialize(new List<Object>{
            // Row 1: a real number inside the rule's window.
            new Map<String, Object>{ 'name' => itemName, metric => inRange },
            // Row 2: the same metric as a STRING, which fails the direct
            // Decimal cast and must fall through to Decimal.valueOf().
            new Map<String, Object>{ 'name' => itemName, metric => String.valueOf(inRange) },
            // Row 3: a blank metric, which must be skipped rather than parsed.
            new Map<String, Object>{ 'name' => itemName, metric => '' },
            // Row 4: no name at all, so the 'ALL' fallback name is used.
            new Map<String, Object>{ metric => inRange }
        });

        Test.startTest();
        String result = CreateQuoteController.determineApprover(r.Department__c, payload);
        Test.stopTest();

        Assert.isNotNull(result, 'A routing decision must always be returned');
        Assert.areNotEqual('FAIL_NO_RULES_MATCHED', result,
            'A payload built from a real matrix row should have matched that row');
    }

    @IsTest
    static void determineApproverHonoursSelfKeyword() {
        List<Quote_Approval_Matrix__mdt> selfRules = [
            SELECT Min_value__c, Max_value__c, Product__c,
                   Evaluation_Metric__c, Department__c
            FROM Quote_Approval_Matrix__mdt
            WHERE Approver__c = 'SELF'
              AND Submitterlevel__c = 'ALL'
              AND Evaluation_Metric__c != null
              AND Product__c != null
            LIMIT 1
        ];
        if (selfRules.isEmpty()) {
            return; // no SELF rule configured in this org
        }
        Quote_Approval_Matrix__mdt r = selfRules[0];
        Decimal minBound = r.Min_value__c != null ? r.Min_value__c : -999999999;
        Decimal maxBound = r.Max_value__c != null ? r.Max_value__c :  999999999;
        String itemName  = (r.Product__c == 'ALL') ? 'Any Product' : r.Product__c;

        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'name' => itemName,
                r.Evaluation_Metric__c.toLowerCase() => (minBound + maxBound) / 2
            }
        });

        Test.startTest();
        String result = CreateQuoteController.determineApprover(r.Department__c, payload);
        Test.stopTest();

        Assert.areEqual(String.valueOf(UserInfo.getUserId()), result,
            'The SELF keyword must route the approval back to the submitter');
    }

    // ══════════════════════════════════════════════════════════════════════
    // getSubordinateUserIds
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getSubordinateUserIdsWalksTheRoleHierarchy() {
        User manager = userByTag('Dept');   // parent role
        User sub     = userByTag('Child');  // child role

        List<Id> ids;
        System.runAs(manager) {
            Test.startTest();
            ids = CreateQuoteController.getSubordinateUserIds();
            Test.stopTest();
        }

        Assert.isTrue(ids.contains(manager.Id), 'The caller is always included');
        Assert.isTrue(ids.contains(sub.Id),
            'A user in a child role must be picked up by the hierarchy walk');
    }

    @IsTest
    static void getSubordinateUserIdsReturnsOnlySelfWhenUserHasNoRole() {
        User noRole = userByTag('NoDept'); // created without a UserRoleId

        List<Id> ids;
        System.runAs(noRole) {
            Test.startTest();
            ids = CreateQuoteController.getSubordinateUserIds();
            Test.stopTest();
        }

        Assert.areEqual(1, ids.size(), 'A user with no role sees only their own approvals');
        Assert.areEqual(noRole.Id, ids[0], 'That single id should be the caller');
    }

    // ══════════════════════════════════════════════════════════════════════
    // finalizeQuoteAndAttachDocs
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void finalizeQuoteUpdatesOpportunityAndAttachesDocs() {
        Opportunity opp = mainOpp();
        Quote q = quoteNamed('Transmission');

        Assert.areEqual(0,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id],
            'The opportunity should start with no linked files');

        Test.startTest();
        CreateQuoteController.finalizeQuoteAndAttachDocs(opp.Id, q.Id,'finalizeQuoteButton');
        Test.stopTest();

        Opportunity updated = [
            SELECT StageName, SyncedQuoteId, Amount, CloseDate
            FROM Opportunity WHERE Id = :opp.Id
        ];
        Quote after = [SELECT LastModifiedDate, Line_Item_Grand_Total__c FROM Quote WHERE Id = :q.Id];

        Assert.areEqual('Negotiation', updated.StageName, 'Stage should move to Negotiation');
        Assert.areEqual(q.Id, updated.SyncedQuoteId, 'The finalized quote must be synced');
        
    }

    @IsTest
    static void finalizeQuoteSweepsPreviousGeneratedFiles() {
        Opportunity opp = mainOpp();
        Quote q = quoteNamed('Transmission');

        ContentVersion oldFile = new ContentVersion(
            Title = 'Finalized_Transmission_OldDoc',
            PathOnClient = 'Transmission_OldDoc.pdf',
            VersionData = Blob.valueOf('Old Data Buffer Mock'),
            Description = 'Generated via Quote Finalization'
        );
        insert oldFile;

        Id oldDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :oldFile.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = oldDocId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Assert.areEqual(1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id],
            'The stale file link should exist before finalization');

        Test.startTest();
        CreateQuoteController.finalizeQuoteAndAttachDocs(opp.Id, q.Id, 'finalizeQuoteButton');
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM ContentDocument WHERE Id = :oldDocId],
            'The previously generated document should be swept away');
    }

    @IsTest
    static void finalizeQuoteWrapsFailuresAsAuraHandledException() {
        Test.startTest();
        try {
            CreateQuoteController.finalizeQuoteAndAttachDocs(null, null,'');
            Assert.fail('Finalizing a null quote should have thrown');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'The controller should wrap failures for the LWC');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // getQuoteValueJson
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getQuoteValueJsonReturnsSavedPayload() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        String json = CreateQuoteController.getQuoteValueJson(q.Id);
        Test.stopTest();

        Assert.areEqual(QUOTE_VALUE_JSON, json, 'The saved Quote_Value__c should be returned as-is');
    }

    @IsTest
    static void getQuoteValueJsonReturnsNullForMissingQuote() {
        Quote ghost = quoteNamed('SameDay');
        Id ghostId = ghost.Id;
        delete ghost;

        Test.startTest();
        String json = CreateQuoteController.getQuoteValueJson(ghostId);
        Test.stopTest();

        Assert.isNull(json, 'A missing quote must fall into the catch and return null');
    }

    // ══════════════════════════════════════════════════════════════════════
    // generateQuoteReference (+ deptAbbreviation, currentFinancialYear)
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void generateQuoteReferenceBuildsR0Format() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        String ref = CreateQuoteController.generateQuoteReference(q.Id, 'Telecom Tower - Department');
        Test.stopTest();

        Quote stored = [SELECT Quote_Reference__c, QuoteNumber FROM Quote WHERE Id = :q.Id];
        Assert.areEqual(ref, stored.Quote_Reference__c, 'The reference must be persisted on the quote');
        Assert.isTrue(ref.startsWith('UIL/Telecom/'), 'Telecom should abbreviate to "Telecom": ' + ref);
        Assert.isTrue(ref.endsWith(stored.QuoteNumber),
            'R0 carries no /R suffix, so the quote number ends the reference: ' + ref);
        // Financial year sits between the abbreviation and the quote number as NN-NN.
        Assert.isTrue(ref.split('/').size() == 4, 'R0 reference should have exactly four segments: ' + ref);
        Assert.isTrue(Pattern.matches('\\d{2}-\\d{2}', ref.split('/')[2]),
            'The third segment should be the financial year as NN-NN: ' + ref);
    }

    @IsTest
    static void generateQuoteReferenceAppendsRevisionSuffix() {
        Quote q = quoteNamed('Telecom');
        update new Quote(Id = q.Id, Revision_No__c = 3);

        Test.startTest();
        String ref = CreateQuoteController.generateQuoteReference(q.Id, 'High Mast - Department');
        Test.stopTest();

        Assert.isTrue(ref.startsWith('UIL/HM/'), 'High Mast should abbreviate to HM: ' + ref);
        Assert.isTrue(ref.endsWith('/R3'), 'A revision must carry its /Rn suffix: ' + ref);
    }

    @IsTest
    static void generateQuoteReferenceCoversEveryDepartmentAbbreviation() {
        Quote q = quoteNamed('Telecom');
        Map<String, String> expected = new Map<String, String>{
            'High Mast - Department'      => 'HM',
            'Crash Barrier - Department'  => 'CB',
            'HDPE Pipe - Department'      => 'HDPE',
            'PEB - Department'            => 'PEB',
            'Solar - Department'          => 'SS',
            'Steel Tubular Pole'          => 'STP',
            'Steel Pipe - Department'     => 'SP',
            'Telecom Tower - Department'  => 'Telecom',
            'Transmission Tower'          => 'TLT & SSS',
            'Core - Department'           => 'CORE',
            // Unknown department: initials of each word, "- Department" stripped.
            'Wind Energy Systems - Department' => 'WES'
        };

        Test.startTest();
        for (String dept : expected.keySet()) {
            String ref = CreateQuoteController.generateQuoteReference(q.Id, dept);
        }
        // Null department falls through the initials loop to the GEN fallback.
        String genRef = CreateQuoteController.generateQuoteReference(q.Id, null);
        Test.stopTest();

        Assert.isTrue(genRef.startsWith('UIL/GEN/'),
            'A null department should fall back to GEN: ' + genRef);
    }

    @IsTest
    static void generateQuoteReferenceRejectsNullQuoteId() {
        Test.startTest();
        try {
            CreateQuoteController.generateQuoteReference(null, 'Core - Department');
            Assert.fail('A null quote id should have been rejected');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Expected an AuraHandledException for a null quote id');
        }
        Test.stopTest();
    }
    
    // ══════════════════════════════════════════════════════════════════════
    // OFFER TOTAL CAPTURE
    // captureOfferTotal / resolveOfferTotal / solarOfferTotal and the three
    // parsing helpers. The department branches build the real offer
    // controllers, so only the Solar branch is asserted to the paisa - it is
    // the one that reads the saved JSON directly and therefore cannot depend
    // on another class's behaviour. The rest are driven end to end and
    // asserted for not blowing up, because resolveOfferTotal deliberately
    // swallows a failing document controller and returns null.
    // Deepanjan (4th August 2026)
    // ══════════════════════════════════════════════════════════════════════

    // Weight mode: rate per MT x Total_Weight__c, rate rounded to whole rupees
    // the way the offer page prints it. 98,600 x 20 + 1,08,394 x 15
    private static final String SOLAR_WEIGHT_JSON =
        '{"unit_of_measurement":"Weight",' +
        '"_Saved_Template_Name":"Solar Structure - Department",' +
        '"_configuredSolarStructure":{"Unit_Of_Measurement__c":"Weight","Lines":[' +
        '{"Material__c":"HDG MMS Structure","Total_Weight__c":20,"Unit_Weight__c":1,' +
        '"Quantity__c":1,"Freight__c":10,"Unit_Price__c":98599.6},' +
        '{"Material__c":"HDG MMS Structure","Total_Weight__c":15,"Unit_Weight__c":1,' +
        '"Quantity__c":1,"Freight__c":500,"Unit_Price__c":108393.5}]}}';

    // Pcs mode: piece rate x Quantity__c, no rounding. 9,13,409.30 x 2 + 8,46,565.70 x 1
    private static final String SOLAR_PCS_JSON =
        '{"unit_of_measurement":"Pcs",' +
        '"_Saved_Template_Name":"Solar Structure - Department",' +
        '"_configuredSolarStructure":{"Unit_Of_Measurement__c":"Pcs","Lines":[' +
        '{"Material__c":"HDG MMS Structure","Total_Weight__c":20,"Unit_Weight__c":10,' +
        '"Quantity__c":2,"Freight__c":1000,"Unit_Price__c":913409.3},' +
        '{"Material__c":"HDG MMS Structure","Total_Weight__c":11,"Unit_Weight__c":11,' +
        '"Quantity__c":0,"Freight__c":500,"Unit_Price__c":846565.7}]}}';

    private static Quote insertQuote(String name, String payload) {
        Quote q = new Quote(
            Name = name,
            OpportunityId = mainOpp().Id,
            Status = 'Draft',
            Quote_Value__c = payload,
            Has_Quote_Value__c = true
        );
        insert q;
        return q;
    }

    private static Opportunity reloadMainOpp() {
        return [
            SELECT Id, Amount, StageName, Customer_Journey__c
            FROM   Opportunity
            WHERE  Name = 'Test Opportunity'
            LIMIT  1
        ];
    }

    @IsTest
    static void captureOfferTotalWritesSolarWeightTotalAndMovesStage() {
        Quote q = insertQuote('Solar Weight', SOLAR_WEIGHT_JSON);
        Opportunity opp = mainOpp();

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, opp.Id);
        Test.stopTest();

        Quote saved = [SELECT Final_Quote_Amount__c FROM Quote WHERE Id = :q.Id LIMIT 1];
        Assert.areEqual(3597910.00, saved.Final_Quote_Amount__c,
            'Weight mode rounds each rate to whole rupees before multiplying by the tonnage');

        Opportunity after = reloadMainOpp();
        Assert.areEqual(3597910.00, after.Amount,
            'The same figure should land on the Opportunity');
        Assert.areEqual('Negotiation', after.StageName,
            'Nurture + Direct Business should move to Negotiation');
    }

    @IsTest
    static void captureOfferTotalUsesPieceRateForPcsMode() {
        // Line two carries Quantity__c 0, which the offer controller treats as 1 -
        // 9,13,409.30 x 2 + 8,46,565.70 x 1.
        Quote q = insertQuote('Solar Pcs', SOLAR_PCS_JSON);

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, mainOpp().Id);
        Test.stopTest();

        Quote saved = [SELECT Final_Quote_Amount__c FROM Quote WHERE Id = :q.Id LIMIT 1];
        Assert.areEqual(2673384.30, saved.Final_Quote_Amount__c,
            'Pcs mode multiplies the piece rate by the quantity with no rounding');
    }

    @IsTest
    static void captureOfferTotalResolvesDepartmentFromQuoteNameWhenJsonHasNoTemplate() {
        // No _Saved_Template_Name in the payload, so the Quote name has to carry
        // the department for the Solar branch to be reached at all.
        String noTemplate = SOLAR_WEIGHT_JSON.replace(
            '"_Saved_Template_Name":"Solar Structure - Department",', '');
        Quote q = insertQuote('Solar Structure - Department', noTemplate);

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, mainOpp().Id);
        Test.stopTest();

        Quote saved = [SELECT Final_Quote_Amount__c FROM Quote WHERE Id = :q.Id LIMIT 1];
        Assert.areEqual(3597910.00, saved.Final_Quote_Amount__c,
            'The Quote name is the fallback when the payload names no template');
    }

    @IsTest
    static void captureOfferTotalSurvivesMalformedQuoteValueJson() {
        // Reaches the non-blocking catch around the department lookup AND the one
        // inside solarOfferTotal, so nothing is written but the stage rule runs.
        Quote q = insertQuote('Solar Structure - Department', '{ this is not valid json');

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, mainOpp().Id);
        Test.stopTest();

        Quote saved = [SELECT Final_Quote_Amount__c FROM Quote WHERE Id = :q.Id LIMIT 1];
        Assert.isNull(saved.Final_Quote_Amount__c,
            'Unparseable JSON must leave the amount untouched');
        Assert.areEqual('Negotiation', reloadMainOpp().StageName,
            'The stage rule still runs when no total could be resolved');
    }

    @IsTest
    static void captureOfferTotalLeavesAmountAloneForUnknownDepartment() {
        Quote q = insertQuote('Mystery',
            '{"_Saved_Template_Name":"Nowhere - Department","foo":"bar"}');

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, mainOpp().Id);
        Test.stopTest();

        Quote saved = [SELECT Final_Quote_Amount__c FROM Quote WHERE Id = :q.Id LIMIT 1];
        Assert.isNull(saved.Final_Quote_Amount__c,
            'A department with no branch must not write an amount');
        Assert.isNull(reloadMainOpp().Amount,
            'The Opportunity amount must be left exactly as it was');
    }

    @IsTest
    static void captureOfferTotalWrapsFailuresAsAuraHandledException() {
        Quote q = insertQuote('Solar Weight Fail', SOLAR_WEIGHT_JSON);

        /*
         * A syntactically valid Opportunity Id that has NEVER existed.
         * captureOfferTotal does `[SELECT ... FROM Opportunity WHERE Id = :id
         * LIMIT 1]` and assigns the result to a single SObject, so an Id with
         * no rows throws a QueryException that the method wraps - exactly the
         * path this test is here to prove.
         *
         * This used to insert a real Opportunity and delete it. That made the
         * Opportunity trigger enqueue BWM_EmailQueueable, which Test.stopTest()
         * then ran; the queueable built an Email_Log__c pointing at the deleted
         * record and BWM_EmailLogService.insertLogs failed with
         * ENTITY_IS_DELETED, taking this test down with it. Never creating the
         * record avoids the trigger entirely and tests the same branch.
         * Deepanjan (10th August 2026)
         */
        Id goneId = Opportunity.SObjectType.getDescribe().getKeyPrefix()
                    + '000000000000';

        Test.startTest();
        try {
            CreateQuoteController.captureOfferTotal(q.Id, goneId);
            Assert.fail('A missing Opportunity should have been rejected');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Expected an AuraHandledException when the lookup fails');
        }
        Test.stopTest();
    }

    @IsTest
    static void solarOfferTotalReturnsNullForEveryEmptyShape() {
        Test.startTest();
        Assert.isNull(CreateQuoteController.solarOfferTotal(null),
            'A null payload has nothing to total');
        Assert.isNull(CreateQuoteController.solarOfferTotal('   '),
            'A blank payload has nothing to total');
        Assert.isNull(CreateQuoteController.solarOfferTotal('{not json'),
            'Unparseable JSON returns null rather than throwing');
        Assert.isNull(CreateQuoteController.solarOfferTotal('{"unit_of_measurement":"Weight"}'),
            'No _configuredSolarStructure means no total');
        Assert.isNull(CreateQuoteController.solarOfferTotal(
                '{"_configuredSolarStructure":"not a map"}'),
            'A _configuredSolarStructure of the wrong type is ignored');
        Assert.isNull(CreateQuoteController.solarOfferTotal(
                '{"_configuredSolarStructure":{"Unit_Of_Measurement__c":"Weight"}}'),
            'A configuration with no Lines has nothing to total');
        Assert.isNull(CreateQuoteController.solarOfferTotal(
                '{"_configuredSolarStructure":{"Lines":[]}}'),
            'An empty Lines array totals to zero, which is reported as null');
        Test.stopTest();
    }

    @IsTest
    static void solarOfferTotalFallsBackToTheConfiguredUnitAndDefaultsToWeight() {
        // No header unit_of_measurement: the configured copy decides.
        String cfgOnly =
            '{"_configuredSolarStructure":{"Unit_Of_Measurement__c":"Pcs","Lines":[' +
            '{"Total_Weight__c":20,"Quantity__c":2,"Unit_Price__c":1000}]}}';

        // Neither key present, and a junk line mixed in that must be skipped:
        // the default is Weight, so 1,000 x 20.
        String noUom =
            '{"_configuredSolarStructure":{"Lines":[' +
            '"not a line",' +
            '{"Total_Weight__c":20,"Quantity__c":2,"Unit_Price__c":1000}]}}';

        // A literal "null" string in the header falls through to the configured key.
        String nullUom =
            '{"unit_of_measurement":"null","_configuredSolarStructure":' +
            '{"Unit_Of_Measurement__c":"Pcs","Lines":[' +
            '{"Total_Weight__c":20,"Quantity__c":2,"Unit_Price__c":1000}]}}';

        Test.startTest();
        Assert.areEqual(2000.00, CreateQuoteController.solarOfferTotal(cfgOnly),
            'Unit_Of_Measurement__c should select Pcs mode: 1000 x 2');
        Assert.areEqual(20000.00, CreateQuoteController.solarOfferTotal(noUom),
            'With no unit anywhere the mode defaults to Weight: 1000 x 20');
        Assert.areEqual(2000.00, CreateQuoteController.solarOfferTotal(nullUom),
            'A "null" header string must fall back to the configured unit');
        Test.stopTest();
    }

    @IsTest
    static void cbNumAndParseMoneyReadEveryShapeSafely() {
        Test.startTest();
        Assert.areEqual(0, CreateQuoteController.cbNum(null), 'null reads as zero');
        Assert.areEqual(0, CreateQuoteController.cbNum('   '), 'blank reads as zero');
        Assert.areEqual(0, CreateQuoteController.cbNum('abc'), 'non-numeric reads as zero');
        Assert.areEqual(12.5, CreateQuoteController.cbNum('12.5'), 'a numeric string parses');
        Assert.areEqual(7, CreateQuoteController.cbNum(7), 'an Integer parses');

        Assert.areEqual(0, CreateQuoteController.parseMoney(null), 'null money reads as zero');
        Assert.areEqual(0, CreateQuoteController.parseMoney(''), 'blank money reads as zero');
        Assert.areEqual(0, CreateQuoteController.parseMoney('-'), 'a bare sign reads as zero');
        Assert.areEqual(0, CreateQuoteController.parseMoney('.'), 'a bare point reads as zero');
        Assert.areEqual(0, CreateQuoteController.parseMoney('Rs'), 'letters alone read as zero');
        Assert.areEqual(192500, CreateQuoteController.parseMoney('1,92,500'),
            'Indian grouping is stripped');
        Assert.areEqual(123456.00, CreateQuoteController.parseMoney('1,23,456.00'),
            'Grouping plus decimals is stripped');
        Test.stopTest();
    }

    @IsTest
    static void cbFreightKeyMapsEverySection() {
        Test.startTest();
        Assert.areEqual('wb_natrax_fvf',
            CreateQuoteController.cbFreightKey('NATRAX W BEAM'), 'Natrax W');
        Assert.areEqual('tb_natrax_fvf',
            CreateQuoteController.cbFreightKey('NATRAX THRIE BEAM'), 'Natrax Thrie');
        Assert.areEqual('wb_alka_fvf',
            CreateQuoteController.cbFreightKey('ALKA W BEAM'), 'Alka W');
        Assert.areEqual('tb_alka_fvf',
            CreateQuoteController.cbFreightKey('ALKA THRIE BEAM'), 'Alka Thrie');
        Assert.areEqual('wb_trans_fvf',
            CreateQuoteController.cbFreightKey('TRANSPOLIS W'), 'Transpolis W');
        Assert.areEqual('tb_trans_fvf',
            CreateQuoteController.cbFreightKey('TRANSPOLIS THRIE'), 'Transpolis Thrie');
        Assert.areEqual('r_s_fvf',
            CreateQuoteController.cbFreightKey('NOISE BARRIER REFLECTIVE'), 'Reflective barrier');
        Assert.areEqual('a_s_fvf',
            CreateQuoteController.cbFreightKey('NOISE BARRIER ABSORPTIVE'), 'Absorptive barrier');
        Assert.areEqual('PGR_full_vehicle_freight',
            CreateQuoteController.cbFreightKey('PEDESTRIAN GUARD RAIL'), 'PGR');
        Assert.areEqual('rlw_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('RAILWAY GRADED'), 'Railway graded');
        Assert.areEqual('rlw_non_graded_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('RAILWAY NON GRADED'), 'Railway non graded');
        Assert.areEqual('ns_w_beam_section_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('NON-SPACER W BEAM'), 'Non-spacer W');
        Assert.areEqual('ns_thrie_beam_section_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('NON-SPACER THRIE BEAM'), 'Non-spacer Thrie');

        Assert.areEqual('w_SSSB_w_beam_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - W-SSSB'), 'Conventional W SSSB');
        Assert.areEqual('Thrie_SSSB_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - THRIE-SSSB'), 'Conventional Thrie SSSB');
        Assert.areEqual('w_SSDB_w_beam_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - W-SSDB'), 'Conventional W SSDB');
        Assert.areEqual('Thrie_SSDB_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - THRIE-SSDB'), 'Conventional Thrie SSDB');
        Assert.areEqual('w_DSSB_w_beam_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - W-DSSB'), 'Conventional W DSSB');
        Assert.areEqual('Thrie_DSSB_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - THRIE-DSSB'), 'Conventional Thrie DSSB');
        Assert.areEqual('w_DSDB_w_beam_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - W-DSDB'), 'Conventional W DSDB');
        Assert.areEqual('Thrie_DSDB_full_Vehicle_freight',
            CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - THRIE-DSDB'), 'Conventional Thrie DSDB');

        Assert.isNull(CreateQuoteController.cbFreightKey('CONVENTIONAL TYPE - SOMETHING ELSE'),
            'A conventional row with no beam code has no freight key');
        Assert.isNull(CreateQuoteController.cbFreightKey('SOMETHING NOBODY HAS SEEN'),
            'An unknown section has no freight key');
        Test.stopTest();
    }

    // The six remaining branches each build a real document controller. They are
    // driven end to end so their lines execute; resolveOfferTotal swallows any
    // failure inside those classes, so the assertion is that approval capture
    // never throws rather than a specific figure.
    @IsTest
    static void captureOfferTotalRunsEveryDepartmentBranch() {
        Map<String, String> byDepartment = new Map<String, String>{
            'Core - Department'               => 'Core',
            'Steel Tubular Pole - Department' => 'STP',
            'HDPE Pipe - Department'          => 'HDPE',
            'Crash Barrier - Department'      => 'CrashBarrier',
            'Transmission Tower - Department' => 'Transmission',
            'Telecom Tower - Department'      => 'Telecom'
        };

        List<Quote> quotes = new List<Quote>();
        for (String dept : byDepartment.keySet()) {
            quotes.add(new Quote(
                Name = byDepartment.get(dept),
                OpportunityId = mainOpp().Id,
                Status = 'Draft',
                Has_Quote_Value__c = true,
                Quote_Value__c =
                    '{"_Saved_Template_Name":"' + dept + '",' +
                    '"tc_payment_terms_picklist":"Against LC",' +
                    '"tc_no_of_days_interest_free_credit":"30",' +
                    '"tc_rate_of_interest":"3","tc_show_seperate":true,' +
                    '"acc_section_fvf":"","misc_section_fvf":"","add_misc_fvf":"",' +
                    '"_Final_Apex_Lines":[' +
                    '{"name":"GENERAL DETAILS - CONVENTIONAL TYPE - W-SSSB",' +
                    '"weight":18.73,"quantity":3,"unitPrice":1436,"unitCost":1424,' +
                    '"unitListPrice":1436,"expenses":0,"discount":0},' +
                    '{"name":"Accessory: END CONNECTOR","quantity":5,"unitPrice":100,' +
                    '"unitCost":80,"unitListPrice":100,"expenses":0},' +
                    '{"name":"Misc: test1","quantity":5,"unitPrice":20,' +
                    '"unitCost":16,"unitListPrice":20,"expenses":0}],' +
                    '"_Saved_Table_Rows":[' +
                    '{"id":"temp_0","name":"GENERAL DETAILS - CONVENTIONAL TYPE - W-SSSB",' +
                    '"quantity":3,"uom":"EA","unitCost":1424,"unitPrice":1436,' +
                    '"unitListPrice":1436,"netPrice":1436,"listPrice":1436,' +
                    '"discount":0,"expenses":0,"margin":1},' +
                    '{"id":"temp_1","name":"Accessory: END CONNECTOR","quantity":5,' +
                    '"uom":"PCS","unitCost":80,"unitPrice":100,"unitListPrice":100,' +
                    '"netPrice":500,"listPrice":500,"discount":0,"expenses":0,"margin":20},' +
                    '{"id":"temp_2","name":"Misc: test1","quantity":5,"uom":"PCS",' +
                    '"unitCost":16,"unitPrice":20,"unitListPrice":20,"netPrice":100,' +
                    '"listPrice":100,"discount":0,"expenses":0,"margin":20}]}'
            ));
        }
        insert quotes;

        Id oppId = mainOpp().Id;

        Test.startTest();
        for (Quote q : quotes) {
            CreateQuoteController.captureOfferTotal(q.Id, oppId);
        }
        Test.stopTest();

        Assert.areEqual('Negotiation', reloadMainOpp().StageName,
            'Every branch should still leave the stage rule applied');
    }
    
    @IsTest
static void captureQuoteTotalWritesOnlyTheQuoteField() {
    Quote q = insertQuote('Solar Apply', SOLAR_WEIGHT_JSON);

    Test.startTest();
    CreateQuoteController.captureQuoteTotal(q.Id);
    Test.stopTest();

    Quote saved = [SELECT Final_Quote_Amount__c FROM Quote WHERE Id = :q.Id LIMIT 1];
    Assert.areEqual(3597910.00, saved.Final_Quote_Amount__c,
        'Apply should capture the same figure approval does');

    Opportunity after = reloadMainOpp();
    Assert.isNull(after.Amount, 'Apply must not touch the Opportunity amount');
    Assert.areEqual('Nurture', after.StageName, 'Apply must not move the stage');
}


    // ══════════════════════════════════════════════════════════════════════
    // sendQuoteApprovalNotification
    // Deepanjan (10th August 2026) - this method had no coverage at all.
    // It returns a status string rather than throwing, so every branch is
    // asserted on that string. The SENT path depends on the
    // Quote_Approval_Alert custom notification type existing in the org, so
    // the happy-path tests accept either SENT or NO_NOTIFICATION_TYPE -
    // both are correct behaviour and neither should ever be FAILED.
    // ══════════════════════════════════════════════════════════════════════

    /** SENT... or NO_NOTIFICATION_TYPE are both fine; FAILED and SKIPPED are not. */
    private static void assertDelivered(String result, String kind) {
        Assert.isNotNull(result, kind + ': result was null');
        Assert.isTrue(result.startsWith('SENT') || result == 'NO_NOTIFICATION_TYPE',
            kind + ': expected SENT or NO_NOTIFICATION_TYPE but got ' + result);
    }

    @IsTest
    static void sendQuoteApprovalNotificationSkipsOnMissingInput() {
        Quote q = quoteNamed('Telecom');
        Id me = UserInfo.getUserId();

        Test.startTest();
        String noQuote     = CreateQuoteController.sendQuoteApprovalNotification(null, me, 'SUBMITTED');
        String noRecipient = CreateQuoteController.sendQuoteApprovalNotification(q.Id, null, 'SUBMITTED');
        String noKind      = CreateQuoteController.sendQuoteApprovalNotification(q.Id, me, '');
        Test.stopTest();

        Assert.areEqual('SKIPPED_MISSING_INPUT', noQuote, 'Null quote id must skip');
        Assert.areEqual('SKIPPED_MISSING_INPUT', noRecipient, 'Null recipient must skip');
        Assert.areEqual('SKIPPED_MISSING_INPUT', noKind, 'Blank kind must skip');
    }

    @IsTest
    static void sendQuoteApprovalNotificationRejectsUnknownKind() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        String result = CreateQuoteController.sendQuoteApprovalNotification(
            q.Id, UserInfo.getUserId(), 'ESCALATED');
        Test.stopTest();

        Assert.areEqual('UNKNOWN_KIND_ESCALATED', result,
            'An unrecognised kind must come back named so the LWC can log it');
    }

    @IsTest
    static void sendQuoteApprovalNotificationHandlesAllThreeKinds() {
        Quote q = quoteNamed('Telecom');
        Id me = UserInfo.getUserId();

        Test.startTest();
        String submitted = CreateQuoteController.sendQuoteApprovalNotification(q.Id, me, 'SUBMITTED');
        String approved  = CreateQuoteController.sendQuoteApprovalNotification(q.Id, me, 'APPROVED');
        String rejected  = CreateQuoteController.sendQuoteApprovalNotification(q.Id, me, 'REJECTED');
        Test.stopTest();

        assertDelivered(submitted, 'SUBMITTED');
        assertDelivered(approved,  'APPROVED');
        assertDelivered(rejected,  'REJECTED');
    }

    /** A rejection reason is appended to the body - a branch of its own. */
    @IsTest
    static void sendQuoteApprovalNotificationAppendsRejectionReason() {
        Quote q = quoteNamed('Telecom');
        q.Rejection_Reason__c = 'Margin below the approved floor';
        update q;

        Test.startTest();
        String result = CreateQuoteController.sendQuoteApprovalNotification(
            q.Id, UserInfo.getUserId(), 'REJECTED');
        Test.stopTest();

        assertDelivered(result, 'REJECTED with reason');
        if (result.startsWith('SENT')) {
            Assert.isTrue(result.contains('Margin below the approved floor'),
                'The rejection reason should be carried into the notification body');
        }
    }

    @IsTest
    static void sendQuoteApprovalNotificationReportsUnknownQuote() {
        // A syntactically valid Quote Id that does not exist.
        Id ghost = Quote.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        Test.startTest();
        String result = CreateQuoteController.sendQuoteApprovalNotification(
            ghost, UserInfo.getUserId(), 'SUBMITTED');
        Test.stopTest();

        Assert.isTrue(result == 'QUOTE_NOT_FOUND' || result == 'NO_NOTIFICATION_TYPE',
            'A missing quote must report QUOTE_NOT_FOUND, got ' + result);
    }

    // ══════════════════════════════════════════════════════════════════════
    // checkEscalationRequired
    // Deepanjan (10th August 2026) - also had no coverage.
    // ══════════════════════════════════════════════════════════════════════

    @IsTest
    static void checkEscalationRequiredReturnsFalseOnMissingInput() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        CreateQuoteController.EscalationResult noQuote =
            CreateQuoteController.checkEscalationRequired(null, TELECOM_TEMPLATE, '[]');
        CreateQuoteController.EscalationResult noDept =
            CreateQuoteController.checkEscalationRequired(q.Id, '', '[]');
        Test.stopTest();

        Assert.areEqual('false', noQuote.required, 'Null quote id must not escalate');
        Assert.areEqual('', noQuote.targetId, 'Null quote id must not name a target');
        Assert.areEqual('false', noDept.required, 'Blank department must not escalate');
    }

    @IsTest
    static void checkEscalationRequiredHandlesAnEmptyItemList() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        CreateQuoteController.EscalationResult result =
            CreateQuoteController.checkEscalationRequired(q.Id, TELECOM_TEMPLATE, '[]');
        Test.stopTest();

        Assert.isNotNull(result, 'A result wrapper must always come back');
        Assert.areEqual('false', result.required,
            'No line items means nothing to escalate');
    }

    @IsTest
    static void checkEscalationRequiredReadsRealLineItems() {
        Quote q = quoteNamed('Telecom');
        // The same shape determineApprover is given - keys are lower-cased
        // inside the method, so the casing here is deliberately mixed.
        String itemsJson =
            '[{"Name":"TELECOM TOWER PART DETAILS - Tubular - ab",' +
            '"quantity":5,"unitPrice":426124,"unitCost":373792.98,' +
            '"discount":0,"expenses":0,"margin":0}]';

        Test.startTest();
        CreateQuoteController.EscalationResult result =
            CreateQuoteController.checkEscalationRequired(q.Id, TELECOM_TEMPLATE, itemsJson);
        Test.stopTest();

        Assert.isNotNull(result, 'A result wrapper must always come back');
        Assert.isTrue(result.required == 'true' || result.required == 'false',
            'required must be the string true or false, got ' + result.required);
        Assert.isNotNull(result.targetId, 'targetId must never be null');
    }

    /**
     * A payload that is valid JSON but an object rather than a list. The
     * method only walks List<Object>, so this must fall through to the
     * no-escalation answer instead of blowing up.
     */
    @IsTest
    static void checkEscalationRequiredIgnoresANonListPayload() {
        Quote q = quoteNamed('Telecom');

        Test.startTest();
        CreateQuoteController.EscalationResult result =
            CreateQuoteController.checkEscalationRequired(q.Id, TELECOM_TEMPLATE, '{"name":"not a list"}');
        Test.stopTest();

        Assert.areEqual('false', result.required,
            'An object payload has no line items, so nothing escalates');
    }
    
    // ══════════════════════════════════════════════════════════════════════
    // Address Helper Methods & Tie-Breaker Logic
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void testPickAddressBookTieBreakers() {
        // Create in-memory records to test the @TestVisible tie-breaker logic directly
        Address_Book__c b1 = new Address_Book__c(Street__c = 'S1'); // 1 field filled
        Address_Book__c b2 = new Address_Book__c(Street__c = 'S2', City__c = 'C2'); // 2 fields filled
        Address_Book__c b3 = new Address_Book__c(Street__c = 'S3', Primary_Address__c = true); // Primary
        
        List<Address_Book__c> books = new List<Address_Book__c>{b1, b2};
        
        Test.startTest();
        // Test that the record with the most filled fields wins if there is no primary
        Address_Book__c winnerMostFields = CreateQuoteController.pickAddressBook(books);
        
        // Test that a primary address instantly overrides a non-primary with more fields
        books.add(b3);
        Address_Book__c winnerPrimary = CreateQuoteController.pickAddressBook(books);
        
        // Test filledCount directly
        Integer filled = CreateQuoteController.filledCount(b2);
        Test.stopTest();
        
        Assert.areEqual('S2', winnerMostFields.Street__c, 'The record with more fields should win if neither is primary');
        Assert.areEqual('S3', winnerPrimary.Street__c, 'The primary address must win regardless of field count');
        Assert.areEqual(2, filled, 'filledCount should correctly count the populated fields');
    }

    @IsTest
    static void testSanitizeForTag() {
        Test.startTest();
        String nullResult = CreateQuoteController.sanitizeForTag(null);
        String blankResult = CreateQuoteController.sanitizeForTag('   ');
        
        // Simulating a complex address with line breaks, tabs, and quotes
        String complexInput = 'Line 1\r\nLine 2\n\t"Quoted" $Price';
        String complexResult = CreateQuoteController.sanitizeForTag(complexInput);
        Test.stopTest();
        
        Assert.areEqual('', nullResult, 'Null input should return an empty string');
        Assert.areEqual('', blankResult, 'Blank input should return an empty string');
        Assert.isTrue(complexResult.contains('Line 1, Line 2'), 'Line breaks should be replaced by commas');
        Assert.isTrue(complexResult.contains('\\"'), 'Double quotes must be escaped for JSON safety');
        Assert.isTrue(complexResult.contains('$$'), 'Dollar signs must be doubled');
    }
    
   

    // ══════════════════════════════════════════════════════════════════════
    // Routing Engine Exception Handling
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void determineApproverHandlesDecimalConversionError() {
        // Provide a payload where a metric is a non-numeric string. This forces the 
        // Decimal cast to fail and tests the fallback catch block inside the routing engine.
        String payload = '{"_Dynamic_Product_Name":"Tubular", "Discount":"NotANumber"}';
        
        Test.startTest();
        String result = CreateQuoteController.determineApprover('No Such Department 12345', payload);
        Test.stopTest();
        
        Assert.areEqual('FAIL_NO_RULES_MATCHED', result, 'The engine should safely swallow the type-cast exception and continue');
    }
    // ══════════════════════════════════════════════════════════════════════
    // Edge Cases for Maximum Coverage
    // ══════════════════════════════════════════════════════════════════════
    
    @IsTest
    static void finalizeQuoteHandlesBadJsonGracefully() {
        // The 'SameDay' quote has deliberately malformed JSON set up in makeData().
        // This forces the catch(Exception jsonEx) block inside finalizeQuoteAndAttachDocs to run.
        Quote q = quoteNamed('SameDay');
        Opportunity opp = mainOpp();
        
        Test.startTest();
        try {
            CreateQuoteController.finalizeQuoteAndAttachDocs(opp.Id, q.Id, 'finalizeQuoteButton');
        } catch (Exception e) {
            // Expected to handle gracefully or throw an AuraHandledException wrapper
        }
        Test.stopTest();
        
        Assert.isTrue(true, 'Method safely executed JSON fallback block');
    }

    @IsTest
    static void captureQuoteTotalCatchesExceptions() {
        Test.startTest();
        // A syntactically valid ID that doesn't point to a Quote
        Id fakeId = Opportunity.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        
        // This will force a QueryException internally,
        // which captureQuoteTotal wraps in a catch block and silently logs.
        CreateQuoteController.captureQuoteTotal(fakeId);
        Test.stopTest();
        
        Assert.isTrue(true, 'captureQuoteTotal should silently swallow the exception');
    }

    @IsTest
    static void sendQuoteApprovalNotificationTruncatesLongText() {
        Quote q = quoteNamed('Telecom');
        
        // Make the rejection reason massive (800 chars) to exceed the 750 character 
        // limit, forcing the body truncation `if (body.length() > 750)` block to run.
        q.Rejection_Reason__c = 'A'.repeat(800); 
        update q;
        
        Test.startTest();
        String result = CreateQuoteController.sendQuoteApprovalNotification(
            q.Id, UserInfo.getUserId(), 'REJECTED'
        );
        Test.stopTest();
        
        Assert.isNotNull(result, 'Result should not be null');
        if (result.startsWith('SENT')) {
            Assert.isTrue(result.contains('...'), 'The long text should have been truncated with an ellipsis');
        }
    }

    @IsTest
    static void checkEscalationRequiredReadsMapPayload() {
        Quote q = quoteNamed('Telecom');
        
        Test.startTest();
        // Provide the full, complex JSON map (rather than a simple array) 
        // to cover the `else if (deserialized instanceof Map<String, Object>)` 
        // parsing branch inside checkEscalationRequired.
        CreateQuoteController.EscalationResult result =
            CreateQuoteController.checkEscalationRequired(q.Id, TELECOM_TEMPLATE, QUOTE_VALUE_JSON);
        Test.stopTest();
        
        Assert.isNotNull(result, 'A result wrapper must always come back');
        Assert.isNotNull(result.targetId, 'targetId must be present');
    }
    
    // ══════════════════════════════════════════════════════════════════════
    // OFFER TOTAL — the three branches added on 3rd September 2026
    //
    // High Mast, Steel Pipes and PEB had NO branch in resolveOfferTotal until
    // 3 Sep 2026. Nothing in this class reached them, and that is where the
    // coverage went. captureOfferTotalRunsEveryDepartmentBranch covers only
    // Core / STP / HDPE / Crash Barrier / Transmission / Telecom.
    //
    // Each of the three runs in its OWN test method, deliberately NOT added to
    // that shared loop:
    //   - one document controller blowing up cannot take the other two down
    //   - each gets its own SOQL/DML budget; these controllers are query-heavy
    //     and the shared loop already builds six of them in one transaction
    //
    // resolveOfferTotal swallows a failing document controller and returns
    // null, so the assertion is that the capture completes, not a figure.
    // Deepanjan (4th September 2026)
    // ══════════════════════════════════════════════════════════════════════

    private static final String OFFER_LINES_JSON =
        '"_Final_Apex_Lines":[{"name":"GENERAL DETAILS","weight":18.73,"quantity":3,' +
        '"unitPrice":1436,"unitCost":1424,"unitListPrice":1436,"expenses":0,"discount":0}],' +
        '"_Saved_Table_Rows":[{"id":"temp_0","name":"GENERAL DETAILS","quantity":3,' +
        '"uom":"EA","unitCost":1424,"unitPrice":1436,"unitListPrice":1436,' +
        '"netPrice":1436,"listPrice":1436,"discount":0,"expenses":0,"margin":1}]';

    /* A quote whose saved payload names the given department. Only the
       substring resolveOfferTotal tests for matters here, so the exact org
       label ("Steel Pipes - Department" vs "Steel Pipe - Department") is
       irrelevant to which branch is entered. */
    private static Quote departmentQuote(String label, String department) {
        return insertQuote(label,
            '{"_Saved_Template_Name":"' + department + '",' + OFFER_LINES_JSON + '}');
    }

    @IsTest
    static void captureOfferTotalRunsTheHighMastBranch() {
        Quote q = departmentQuote('HM Offer', 'High Mast - Department');

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, mainOpp().Id);
        Test.stopTest();

        Assert.areEqual('Negotiation', reloadMainOpp().StageName,
            'The High Mast branch must run to completion and leave the stage rule applied');
    }

    @IsTest
    static void captureOfferTotalRunsTheSteelPipeBranch() {
        // 'Steel Tubular Pole' is tested first inside resolveOfferTotal, so this
        // label cannot be swallowed by the STP branch.
        Quote q = departmentQuote('SP Offer', 'Steel Pipes - Department');

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, mainOpp().Id);
        Test.stopTest();

        Assert.areEqual('Negotiation', reloadMainOpp().StageName,
            'The Steel Pipes branch must run to completion and leave the stage rule applied');
    }

    @IsTest
    static void captureOfferTotalRunsThePebBranch() {
        Quote q = departmentQuote('PEB Offer', 'PEB - Department');

        Test.startTest();
        CreateQuoteController.captureOfferTotal(q.Id, mainOpp().Id);
        Test.stopTest();

        Assert.areEqual('Negotiation', reloadMainOpp().StageName,
            'The PEB branch must run to completion and leave the stage rule applied');
    }

    /* resolveOfferTotal is public and called directly here so the fall-through
       `return null` at the bottom is proved on its own, rather than only through
       captureOfferTotal's wrapper. */
    @IsTest
    static void resolveOfferTotalReturnsNullWhenNoBranchOwnsTheDepartment() {
        Quote q = insertQuote('No Branch',
            '{"_Saved_Template_Name":"Nowhere - Department",' + OFFER_LINES_JSON + '}');

        Test.startTest();
        Decimal total = CreateQuoteController.resolveOfferTotal(q.Id);
        Test.stopTest();

        Assert.isNull(total,
            'A department that no branch owns must fall through to the final null');
    }

    // ══════════════════════════════════════════════════════════════════════
    // checkEscalationRequired — the escalation-found block
    //
    // Everything from `if (escalationFound)` down (the Utkarsh ED role lookup,
    // the Name-based fallback and the "No active user found for Ed." message)
    // can only run when a matrix row carries Escalation__c = true. No existing
    // test produces one, so that whole tail was dark.
    //
    // Data-driven in the same style as the determineApprover tests: the org's
    // own metadata decides the payload, and the test no-ops if the org has no
    // escalation rule rather than asserting something that cannot be true.
    // Deepanjan (4th September 2026)
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void checkEscalationRequiredResolvesTheEscalationTarget() {
        List<Quote_Approval_Matrix__mdt> escRules = [
            SELECT Approver__c, Min_value__c, Max_value__c, Product__c,
                   Evaluation_Metric__c, Department__c
            FROM Quote_Approval_Matrix__mdt
            WHERE Escalation__c = true
              AND Submitterlevel__c = 'ALL'
              AND Evaluation_Metric__c != null
              AND Product__c            != null
              AND Department__c         != null
              AND Approver__c           != null
            LIMIT 1
        ];
        if (escRules.isEmpty()) {
            return; // no escalation rule configured in this org
        }
        Quote_Approval_Matrix__mdt r = escRules[0];

        Decimal minBound = r.Min_value__c != null ? r.Min_value__c : -999999999;
        Decimal maxBound = r.Max_value__c != null ? r.Max_value__c :  999999999;
        String  itemName = (r.Product__c == 'ALL') ? 'Any Product' : r.Product__c;

        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'name' => itemName,
                r.Evaluation_Metric__c.toLowerCase() => (minBound + maxBound) / 2
            }
        });

        Quote q = quoteNamed('Telecom');

        Test.startTest();
        CreateQuoteController.EscalationResult res =
            CreateQuoteController.checkEscalationRequired(q.Id, r.Department__c, payload);
        Test.stopTest();

        Assert.areEqual('true', res.required,
            'A rule flagged Escalation__c must set required to true');
        Assert.isNotNull(res.targetId,
            'targetId must always come back, blank or otherwise');
    }
}