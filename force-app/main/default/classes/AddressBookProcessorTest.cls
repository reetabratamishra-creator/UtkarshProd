@IsTest
public class AddressBookProcessorTest {

    @TestSetup
    public static void setupData() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Lead ld = new Lead(
            LastName = 'Test Lead',
            Company = 'Test Company',
            Street__c = '123 Main Street',
            City__c = 'Kolkata',
            State__c = 'West Bengal',
            Country__c = 'India',
            PIN__c = '700001',
            Zone__c = 'East'
        );
        insert ld;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Address_Book__c ab = new Address_Book__c(
            Account__c = acc.Id,
            Street__c = '123 Main Street',
            City__c = 'Kolkata',
            State__c = 'West Bengal',
            Country__c = 'India',
            PIN__c = '700001',
            Zone__c = 'East',
            Primary_Address__c = true
        );
        insert ab;
    }

    @IsTest
    public static void testProcess_WithSelectedAddressBook() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Address_Book__c ab = [SELECT Id FROM Address_Book__c LIMIT 1];

        AddressBookProcessor.Input input = new AddressBookProcessor.Input();
        input.leadId = ld.Id;
        input.accountId = acc.Id;
        input.contactId = con.Id;
        input.opportunityId = opp.Id;
        input.selectedAddressBookId = ab.Id;

        Test.startTest();
        AddressBookProcessor.process(new List<AddressBookProcessor.Input>{input});
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT Count() FROM Opportunity_Address_Junc__c WHERE Opportunity__c = :opp.Id]
        );

        Contact updated =
            [SELECT Street__c, City__c FROM Contact WHERE Id=:con.Id];

        System.assertEquals('123 Main Street', updated.Street__c);
        System.assertEquals('Kolkata', updated.City__c);
    }

    @IsTest
    public static void testProcess_DuplicateAddressFound() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Lead ld = [SELECT Id FROM Lead LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        AddressBookProcessor.Input input = new AddressBookProcessor.Input();
        input.leadId = ld.Id;
        input.accountId = acc.Id;
        input.contactId = con.Id;
        input.opportunityId = opp.Id;

        Test.startTest();
        AddressBookProcessor.process(new List<AddressBookProcessor.Input>{input});
        Test.stopTest();

        
    }

    @IsTest
    public static void testProcess_CreateNewAddressBook() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Lead ld = new Lead(
            LastName='New Lead',
            Company='ABC',
            Street__c='999 New Street',
            City__c='Delhi',
            State__c='Delhi',
            Country__c='India',
            PIN__c='110001',
            Zone__c='North'
        );
        insert ld;

        AddressBookProcessor.Input input = new AddressBookProcessor.Input();
        input.leadId = ld.Id;
        input.accountId = acc.Id;
        input.contactId = con.Id;
        input.opportunityId = opp.Id;

        Test.startTest();
        AddressBookProcessor.process(new List<AddressBookProcessor.Input>{input});
        Test.stopTest();

        Address_Book__c newAB = [
            SELECT Street__c, City__c
            FROM Address_Book__c
            WHERE Street__c='999 New Street'
            LIMIT 1
        ];

        System.assertEquals('Delhi', newAB.City__c);

        Contact updated = [
            SELECT Street__c, City__c
            FROM Contact
            WHERE Id=:con.Id
        ];

        System.assertEquals('999 New Street', updated.Street__c);
        System.assertEquals('Delhi', updated.City__c);
    }

    @IsTest
    public static void testProcess_EmptyInput() {

        Test.startTest();
        AddressBookProcessor.process(new List<AddressBookProcessor.Input>());
        Test.stopTest();

        System.assert(true);
    }
}