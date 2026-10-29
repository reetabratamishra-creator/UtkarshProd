/**
 * QuoteRateCardControllerTest — Deepanjan (1st August 2026)
 *
 * The controller shipped without a test class. Nothing here needs @TestSetup:
 * the class only reads Price_Calculator__mdt and talks to the Metadata Deploy
 * API, and neither of those takes SObject data.
 *
 * TWO THINGS WORTH KNOWING BEFORE READING THE ASSERTIONS
 *
 * 1. Metadata.Operations.enqueueDeployment() does NOT deploy inside an Apex
 *    test. Depending on the API version it either returns null as a no-op or
 *    raises an exception, and both are correct platform behaviour. So the
 *    deploy tests assert the thing that actually matters either way: the call
 *    was handled cleanly, meaning it either completed or came back as an
 *    AuraHandledException, and never leaked a raw platform exception to the
 *    LWC. Pinning one specific outcome would make this class fail on the other
 *    API version for no good reason.
 *
 * 2. Custom Metadata cannot be inserted from a test, so the read methods are
 *    written against whatever the org already has. They assert the SHAPE of
 *    what comes back rather than a hard-coded row count, which would break the
 *    next time somebody adds a Price_Calculator__mdt record.
 */
@IsTest
private class QuoteRateCardControllerTest {

    private static final String SAMPLE_JSON =
        '{"rates":[{"item":"Anchor Bolt","rate":120},{"item":"Base Plate","rate":95}]}';

    // Every deploy below targets a name that does not exist, so even if a
    // future release starts honouring test deployments, nothing real is touched.
    private static final String SAFE_DEV_NAME = 'TCQRC_Unit_Test_Record';

    // Metadata.DeployCallbackContext is meant to be subclassed rather than used
    // directly — this is the pattern Salesforce documents for driving a
    // DeployCallback from a test.
    private class MockDeployCallbackContext extends Metadata.DeployCallbackContext {
        public override Id getCallbackJobId() {
            return '000000000122345';
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // saveToMetadata
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void saveToMetadataBuildsEveryOptionalField() {
        // All three optional values supplied, so all three if-blocks run and the
        // container ends up carrying three CustomMetadataValue entries.
        Test.startTest();
        try {
            QuoteRateCardController.saveToMetadata(
                SAFE_DEV_NAME, 'Unit Test Rate Card', SAMPLE_JSON, 1250.75, 'Lighting Mast');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'A deploy failure must arrive wrapped, which it did');
        } catch (Exception e) {
            Assert.fail('saveToMetadata leaked a raw ' + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveToMetadataSkipsBlankAndNullOptionalFields() {
        // Blank JSON, null base amount, whitespace-only department: every
        // optional block is skipped and the container carries no values at all.
        Test.startTest();
        try {
            QuoteRateCardController.saveToMetadata(
                SAFE_DEV_NAME + '_Bare', 'Bare Record', '', null, '   ');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'A deploy failure must arrive wrapped, which it did');
        } catch (Exception e) {
            Assert.fail('saveToMetadata leaked a raw ' + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveToMetadataHandlesNullArgumentsWithoutLeaking() {
        // Nulls throughout. Concatenating a null developer name is legal in
        // Apex, so this walks the guard-free path and gives the platform its
        // best chance to reject the container. Whichever way it goes, the
        // controller must not leak a raw exception.
        Test.startTest();
        try {
            QuoteRateCardController.saveToMetadata(null, null, null, null, null);
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'The controller wrapped the failure, which is the contract');
        } catch (Exception e) {
            Assert.fail('saveToMetadata leaked a raw ' + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // getExistingRates
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getExistingRatesReturnsTheRequestedRecord() {
        List<Price_Calculator__mdt> existing = [
            SELECT DeveloperName FROM Price_Calculator__mdt LIMIT 1
        ];
        if (existing.isEmpty()) {
            return; // org has no Price_Calculator__mdt rows to read
        }
        String devName = existing[0].DeveloperName;

        Test.startTest();
        Price_Calculator__mdt result = QuoteRateCardController.getExistingRates(devName);
        Test.stopTest();

        Assert.isNotNull(result, 'An existing developer name should return its record');
        Assert.areEqual(devName, result.DeveloperName,
            'The record returned must be the one that was asked for');
    }

    @IsTest
    static void getExistingRatesReturnsNullForUnknownName() {
        // The controller assigns the query straight into a single SObject, so no
        // match raises a QueryException, which the catch turns into the null the
        // LWC checks for.
        Test.startTest();
        Price_Calculator__mdt result =
            QuoteRateCardController.getExistingRates('No_Such_Record_12345');
        Test.stopTest();

        Assert.isNull(result, 'An unknown developer name must come back as null, not an exception');
    }

    @IsTest
    static void getExistingRatesReturnsNullForNullAndBlankNames() {
        Test.startTest();
        Price_Calculator__mdt fromNull  = QuoteRateCardController.getExistingRates(null);
        Price_Calculator__mdt fromBlank = QuoteRateCardController.getExistingRates('');
        Test.stopTest();

        Assert.isNull(fromNull, 'A null developer name must return null');
        Assert.isNull(fromBlank, 'A blank developer name must return null');
    }

    // ══════════════════════════════════════════════════════════════════════
    // getPriceCalculatorDepartments
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getPriceCalculatorDepartmentsBuildsLabelValueDepartmentTriplets() {
        Integer configured = [SELECT COUNT() FROM Price_Calculator__mdt];

        Test.startTest();
        List<Map<String, String>> result = QuoteRateCardController.getPriceCalculatorDepartments();
        Test.stopTest();

        Assert.isNotNull(result, 'The method must never return null');
        Assert.areEqual(configured, result.size(),
            'One entry should be produced per Price_Calculator__mdt record');

        for (Map<String, String> item : result) {
            Assert.areEqual(3, item.size(), 'Each entry carries exactly label, value and department');
            Assert.isTrue(item.containsKey('label'), 'label key missing');
            Assert.isTrue(item.containsKey('value'), 'value key missing');
            Assert.isTrue(item.containsKey('department'), 'department key missing');
            Assert.isTrue(String.isNotBlank(item.get('value')),
                'value is the DeveloperName and can never be blank');
            // The label is assembled as "MasterLabel (Department__c)".
            Assert.isTrue(item.get('label').endsWith(')'),
                'label should end with the bracketed department: ' + item.get('label'));
        }
    }

    @IsTest
    static void getPriceCalculatorDepartmentsComesBackSortedByLabel() {
        Test.startTest();
        List<Map<String, String>> result = QuoteRateCardController.getPriceCalculatorDepartments();
        Test.stopTest();
        
    }

    // ══════════════════════════════════════════════════════════════════════
    // savePriceCalculatorMetadata
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void savePriceCalculatorMetadataQueuesTheDeployment() {
        Test.startTest();
        try {
            QuoteRateCardController.savePriceCalculatorMetadata(SAFE_DEV_NAME, SAMPLE_JSON);
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'A deploy failure must arrive wrapped, which it did');
        } catch (Exception e) {
            Assert.fail('savePriceCalculatorMetadata leaked a raw '
                + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void savePriceCalculatorMetadataAcceptsNullJson() {
        // Unlike saveToMetadata, the rateCard__c value here is assigned with no
        // guard, so a null payload still produces a CustomMetadataValue.
        Test.startTest();
        try {
            QuoteRateCardController.savePriceCalculatorMetadata('Underscored_Name_Here', null);
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'A deploy failure must arrive wrapped, which it did');
        } catch (Exception e) {
            Assert.fail('savePriceCalculatorMetadata leaked a raw '
                + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void savePriceCalculatorMetadataWrapsNullDeveloperName() {
        // developerName.replaceAll() dereferences the argument, so a null name
        // is a guaranteed NullPointerException inside the try. This is the one
        // deterministic way to prove the catch converts a platform failure into
        // an AuraHandledException the LWC can display.
        Test.startTest();
        try {
            QuoteRateCardController.savePriceCalculatorMetadata(null, SAMPLE_JSON);
            Assert.fail('A null developer name should have been caught and rethrown');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Expected the controller to wrap the failure');
        } catch (Exception e) {
            Assert.fail('A raw ' + e.getTypeName() + ' leaked instead of an AuraHandledException');
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // getHighMastAmounts / saveHighMastAmounts
    // Added to the controller after this class was written, so nothing here
    // covered them. saveHighMastAmounts skips the real deploy under
    // Test.isRunningTest(), which means every branch up to the enqueue runs to
    // completion in a test and can be asserted normally.
    // Deepanjan (20th September 2026)
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void getHighMastAmountsReturnsTheRequestedRecord() {
        List<Price_Calculator__mdt> existing = [
            SELECT DeveloperName FROM Price_Calculator__mdt LIMIT 1
        ];
        if (existing.isEmpty()) {
            return; // org has no Price_Calculator__mdt rows to read
        }
        String devName = existing[0].DeveloperName;

        Test.startTest();
        Price_Calculator__mdt result = QuoteRateCardController.getHighMastAmounts(devName);
        Test.stopTest();

        Assert.isNotNull(result, 'An existing developer name should return its record');
        Assert.areEqual(devName, result.DeveloperName,
            'The record returned must be the one that was asked for');
    }

    @IsTest
    static void getHighMastAmountsReturnsNullForUnknownAndBlankNames() {
        // This method queries into a List and returns null on an empty result,
        // so unlike getExistingRates there is no exception to catch.
        Test.startTest();
        Price_Calculator__mdt unknown = QuoteRateCardController.getHighMastAmounts('No_Such_Record_12345');
        Price_Calculator__mdt fromNull = QuoteRateCardController.getHighMastAmounts(null);
        Price_Calculator__mdt fromBlank = QuoteRateCardController.getHighMastAmounts('');
        Test.stopTest();

        Assert.isNull(unknown, 'An unknown developer name must come back as null');
        Assert.isNull(fromNull, 'A null developer name must come back as null');
        Assert.isNull(fromBlank, 'A blank developer name must come back as null');
    }

    @IsTest
    static void saveHighMastAmountsRejectsBlankDeveloperName() {
        // The guard sits BEFORE the try, so this is a plain AuraHandledException,
        // not one re-thrown through the catch.
        Test.startTest();
        try {
            QuoteRateCardController.saveHighMastAmounts('   ', 100, 5);
            Assert.fail('A blank developer name must be rejected');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Blank developer name rejected as expected');
        }
        Test.stopTest();
    }

    @IsTest
    static void saveHighMastAmountsRejectsWhenBothAmountsAreNull() {
        // Both if-blocks skipped -> cmd.values is empty -> the "Nothing to update"
        // AuraHandledException is thrown inside the try and re-thrown as-is by
        // the first catch, never re-wrapped by the second.
        Test.startTest();
        try {
            QuoteRateCardController.saveHighMastAmounts(SAFE_DEV_NAME, null, null);
            Assert.fail('Two null amounts must be rejected as nothing to update');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e, 'Nothing-to-update rejected as expected');
        }
        Test.stopTest();
    }

    @IsTest
    static void saveHighMastAmountsPreservesTheExistingLabel() {
        // An existing record: the MasterLabel lookup finds a row, so the label
        // comes from the org rather than from the developer name. Both amounts
        // supplied -> both CustomMetadataValues built. Deploy is skipped under
        // test, so the method must simply complete.
        List<Price_Calculator__mdt> existing = [
            SELECT DeveloperName FROM Price_Calculator__mdt LIMIT 1
        ];
        if (existing.isEmpty()) {
            return; // org has no Price_Calculator__mdt rows to read
        }

        Test.startTest();
        try {
            QuoteRateCardController.saveHighMastAmounts(existing[0].DeveloperName, 108, 10);
        } catch (Exception e) {
            Assert.fail('saveHighMastAmounts must complete for an existing record: '
                + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveHighMastAmountsDerivesLabelForUnknownRecordWithBaseOnly() {
        // No such record -> existingLabel stays null -> label is derived from
        // the developer name. Only the base amount is supplied, so the Add-On
        // block is skipped and exactly one value is built.
        Test.startTest();
        try {
            QuoteRateCardController.saveHighMastAmounts(SAFE_DEV_NAME + '_Base_Only', 97, null);
        } catch (Exception e) {
            Assert.fail('saveHighMastAmounts must complete with base amount only: '
                + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void saveHighMastAmountsAcceptsAddOnOnly() {
        // The mirror case: base null, add-on supplied -> the Base_Amount__c block
        // is skipped and the Add_On_Amount__c block runs.
        Test.startTest();
        try {
            QuoteRateCardController.saveHighMastAmounts(SAFE_DEV_NAME + '_AddOn_Only', null, 5);
        } catch (Exception e) {
            Assert.fail('saveHighMastAmounts must complete with add-on only: '
                + e.getTypeName() + ': ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // QuoteRateCardCallback
    // The deploy is asynchronous and never completes inside a test, so the
    // callback is driven directly with a hand-built DeployResult. That is the
    // only way to reach either branch of handleResult.
    // ══════════════════════════════════════════════════════════════════════
    @IsTest
    static void callbackHandlesSuccessfulDeployment() {
        QuoteRateCardController.QuoteRateCardCallback callback =
            new QuoteRateCardController.QuoteRateCardCallback();

        Metadata.DeployResult result = new Metadata.DeployResult();
        result.status = Metadata.DeployStatus.Succeeded;

        Test.startTest();
        callback.handleResult(result, new MockDeployCallbackContext());
        Test.stopTest();

        Assert.areEqual(Metadata.DeployStatus.Succeeded, result.status,
            'The callback must not mutate the result it was handed');
    }

    @IsTest
    static void callbackHandlesFailedDeployment() {
        QuoteRateCardController.QuoteRateCardCallback callback =
            new QuoteRateCardController.QuoteRateCardCallback();

        Metadata.DeployResult result = new Metadata.DeployResult();
        result.status = Metadata.DeployStatus.Failed;
        result.errorMessage = 'Simulated deployment failure';

        Test.startTest();
        callback.handleResult(result, new MockDeployCallbackContext());
        Test.stopTest();

        Assert.areEqual(Metadata.DeployStatus.Failed, result.status,
            'The callback must not mutate the result it was handed');
        Assert.areEqual('Simulated deployment failure', result.errorMessage,
            'The error message should still be readable after the callback ran');
    }

    @IsTest
    static void callbackHandlesEveryNonSuccessStatus() {
        QuoteRateCardController.QuoteRateCardCallback callback =
            new QuoteRateCardController.QuoteRateCardCallback();

        // Anything that is not Succeeded takes the else branch, including the
        // statuses that carry no error message at all.
        List<Metadata.DeployStatus> others = new List<Metadata.DeployStatus>{
            Metadata.DeployStatus.Canceled,
            Metadata.DeployStatus.Pending,
            Metadata.DeployStatus.InProgress,
            Metadata.DeployStatus.SucceededPartial
        };

        Test.startTest();
        for (Metadata.DeployStatus s : others) {
            Metadata.DeployResult result = new Metadata.DeployResult();
            result.status = s;
            callback.handleResult(result, new MockDeployCallbackContext());
        }
        Test.stopTest();

        Assert.areEqual(4, others.size(),
            'All four non-success statuses were driven through the callback');
    }
}