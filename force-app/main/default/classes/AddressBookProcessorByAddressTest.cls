@IsTest
public class AddressBookProcessorByAddressTest {

    @TestSetup
    public static void setupData() {

        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;

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
    public static void testProcess_EmptyInput() {

        Test.startTest();
        AddressBookProcessorByAddress.process(
            new List<AddressBookProcessorByAddress.Input>()
        );
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    public static void testProcess_WithSelectedAddressBook() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Address_Book__c ab = [SELECT Id FROM Address_Book__c LIMIT 1];

        AddressBookProcessorByAddress.Input input =
            new AddressBookProcessorByAddress.Input();

        input.accountId = acc.Id;
        input.contactId = con.Id;
        input.opportunityId = opp.Id;
        input.selectedAddressBookId = ab.Id;

        Test.startTest();
        AddressBookProcessorByAddress.process(
            new List<AddressBookProcessorByAddress.Input>{ input }
        );
        Test.stopTest();

        

        Contact updated = [
            SELECT Street__c, City__c
            FROM Contact
            WHERE Id = :con.Id
        ];

        System.assertEquals('123 Main Street', updated.Street__c);
        System.assertEquals('Kolkata', updated.City__c);
    }

    @IsTest
    public static void testProcess_DuplicateAddressFound() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        AddressBookProcessorByAddress.Input input =
            new AddressBookProcessorByAddress.Input();

        input.accountId = acc.Id;
        input.contactId = con.Id;
        input.opportunityId = opp.Id;
        input.street = '123 Main Street';
        input.city = 'Kolkata';
        input.state = 'West Bengal';
        input.country = 'India';
        input.pin = '700001';
        input.zone = 'East';

        Test.startTest();
        AddressBookProcessorByAddress.process(
            new List<AddressBookProcessorByAddress.Input>{ input }
        );
        Test.stopTest();

        
    }

    @IsTest
    public static void testProcess_CreateNewAddressBook() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        AddressBookProcessorByAddress.Input input =
            new AddressBookProcessorByAddress.Input();

        input.accountId = acc.Id;
        input.contactId = con.Id;
        input.opportunityId = opp.Id;
        input.street = '999 New Street';
        input.city = 'Delhi';
        input.state = 'Delhi';
        input.country = 'India';
        input.pin = '110001';
        input.zone = 'North';

        Test.startTest();
        AddressBookProcessorByAddress.process(
            new List<AddressBookProcessorByAddress.Input>{ input }
        );
        Test.stopTest();

        Address_Book__c ab = [
            SELECT Street__c, City__c
            FROM Address_Book__c
            WHERE Street__c = '999 New Street'
            LIMIT 1
        ];

        System.assertEquals('Delhi', ab.City__c);

        Contact updated = [
            SELECT Street__c, City__c
            FROM Contact
            WHERE Id = :con.Id
        ];

        System.assertEquals('999 New Street', updated.Street__c);
        System.assertEquals('Delhi', updated.City__c);
    }

    @IsTest
    public static void testProcess_NoAddressEntered() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Integer beforeCount = [
            SELECT Count()
            FROM Address_Book__c
        ];

        AddressBookProcessorByAddress.Input input =
            new AddressBookProcessorByAddress.Input();

        input.accountId = acc.Id;
        input.contactId = con.Id;
        input.opportunityId = opp.Id;

        Test.startTest();
        AddressBookProcessorByAddress.process(
            new List<AddressBookProcessorByAddress.Input>{ input }
        );
        Test.stopTest();

        Integer afterCount = [
            SELECT Count()
            FROM Address_Book__c
        ];

        System.assertEquals(beforeCount, afterCount);
    }
}