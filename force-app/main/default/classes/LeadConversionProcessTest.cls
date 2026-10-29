/**
 * @description Test class for LeadConversionProcess.
 *              Verifies that LeadSource is mapped correctly to AccountSource,
 *              Contact LeadSource, and Opportunity LeadSource during Lead conversion.
 */
@IsTest
private class LeadConversionProcessTest {

    @IsTest
    static void testConvertLeadNewAccount() {
        // Create a Lead
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'LeadNewAcc',
            Company = 'New Acc Corp',
            Phone = '1234567890',
            Email = 'testnewacc@example.com',
            LeadSource = 'Web',
            Status = 'Open - Not Contacted',
            Tentative_Closure_Date__c = System.today().addDays(30)
        );
        insert l;

        // Prepare Inputs for conversion
        LeadConversionProcess.Input input = new LeadConversionProcess.Input();
        input.leadId = l.Id;
        input.accId = null;

        Test.startTest();
        List<LeadConversionProcess.Output> outputs = LeadConversionProcess.convertLead(new List<LeadConversionProcess.Input>{input});
        Test.stopTest();

        // Verify conversion success
        System.assertEquals(1, outputs.size(), 'Outputs list should contain exactly 1 element');
        System.assertEquals('Success', outputs[0].status, 'Lead conversion status should be Success');
        System.assertNotEquals(null, outputs[0].accountId, 'Account ID should not be null');
        System.assertNotEquals(null, outputs[0].contactId, 'Contact ID should not be null');
        System.assertNotEquals(null, outputs[0].opportunityId, 'Opportunity ID should not be null');

        // Verify Account Source mapping
        Account acc = [SELECT Id, AccountSource FROM Account WHERE Id = :outputs[0].accountId];
        System.assertEquals('Web', acc.AccountSource, 'AccountSource should be mapped to LeadSource for a new Account');

        // Verify Contact Source mapping
        Contact con = [SELECT Id, LeadSource FROM Contact WHERE Id = :outputs[0].contactId];
        System.assertEquals('Web', con.LeadSource, 'Contact LeadSource should be mapped to LeadSource');

        // Verify Opportunity Source mapping
        Opportunity opp = [SELECT Id, LeadSource FROM Opportunity WHERE Id = :outputs[0].opportunityId];
        System.assertEquals('Web', opp.LeadSource, 'Opportunity LeadSource should be mapped to LeadSource');
    }

    @IsTest
    static void testConvertLeadExistingAccountBlankSource() {
        // Create an existing Account with blank AccountSource and valid Phone
        Account existingAcc = new Account(
            Name = 'Existing Acc Corp',
            AccountSource = null,
            Phone = '1234567890'
        );
        insert existingAcc;

        // Create a Lead with LeadSource
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'LeadExistAccBlank',
            Company = 'Existing Acc Corp',
            Phone = '1234567890',
            Email = 'testexistblank@example.com',
            LeadSource = 'Web',
            Status = 'Open - Not Contacted',
            Tentative_Closure_Date__c = System.today().addDays(30)
        );
        insert l;

        // Prepare Inputs for conversion
        LeadConversionProcess.Input input = new LeadConversionProcess.Input();
        input.leadId = l.Id;
        input.accId = existingAcc.Id;

        Test.startTest();
        List<LeadConversionProcess.Output> outputs = LeadConversionProcess.convertLead(new List<LeadConversionProcess.Input>{input});
        Test.stopTest();

        // Verify conversion success
        System.assertEquals(1, outputs.size(), 'Outputs list should contain exactly 1 element');
        System.assertEquals('Success', outputs[0].status, 'Lead conversion status should be Success');
        System.assertEquals(existingAcc.Id, outputs[0].accountId, 'Converted Account ID should match the existing Account ID');

        // Verify Account Source mapping: blank source should be populated
        Account acc = [SELECT Id, AccountSource FROM Account WHERE Id = :existingAcc.Id];
        System.assertEquals('Web', acc.AccountSource, 'AccountSource should be updated to LeadSource when it was previously blank');
    }

    @IsTest
    static void testConvertLeadExistingAccountPrepopulatedSource() {
        // Create an existing Account with pre-populated AccountSource and valid Phone
        Account existingAcc = new Account(
            Name = 'Existing Acc Corp',
            AccountSource = 'Phone Inquiry',
            Phone = '1234567890'
        );
        insert existingAcc;

        // Create a Lead with LeadSource
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'LeadExistAccPopulated',
            Company = 'Existing Acc Corp',
            Phone = '1234567890',
            Email = 'testexistpopulated@example.com',
            LeadSource = 'Web',
            Status = 'Open - Not Contacted',
            Tentative_Closure_Date__c = System.today().addDays(30)
        );
        insert l;

        // Prepare Inputs for conversion
        LeadConversionProcess.Input input = new LeadConversionProcess.Input();
        input.leadId = l.Id;
        input.accId = existingAcc.Id;

        Test.startTest();
        List<LeadConversionProcess.Output> outputs = LeadConversionProcess.convertLead(new List<LeadConversionProcess.Input>{input});
        Test.stopTest();

        // Verify conversion success
        System.assertEquals(1, outputs.size(), 'Outputs list should contain exactly 1 element');
        System.assertEquals('Success', outputs[0].status, 'Lead conversion status should be Success');
        System.assertEquals(existingAcc.Id, outputs[0].accountId, 'Converted Account ID should match the existing Account ID');

        // Verify Account Source mapping: pre-populated source should NOT be modified
        Account acc = [SELECT Id, AccountSource FROM Account WHERE Id = :existingAcc.Id];
        System.assertEquals('Phone Inquiry', acc.AccountSource, 'AccountSource should NOT be modified when it was already populated');
    }
}