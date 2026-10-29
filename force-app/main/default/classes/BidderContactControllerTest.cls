@IsTest
private class BidderContactControllerTest {

    @TestSetup
    static void setupTestData() {
        // 1. Create a mock Tender record
        // Name is an auto-number field, so we don't assign it manually.
        // If Tender__c has other custom required fields, add them here.
        Tender__c testTender = new Tender__c();
        insert testTender;

        // 2. Create mock Bidder Contact Details linked to the Tender
        List<Bidders_Contact_Details__c> mockContacts = new List<Bidders_Contact_Details__c>();
        
        mockContacts.add(new Bidders_Contact_Details__c(
            Name = 'Alice Smith',
            Email__c = 'alice@example.com',
            Tender__c = testTender.Id
        ));
        
        mockContacts.add(new Bidders_Contact_Details__c(
            Name = 'Bob Jones',
            Email__c = 'bob@example.com',
            Tender__c = testTender.Id
        ));

        insert mockContacts;
    }

    @IsTest
    static void testGetBidderContacts_WithValidTender() {
        // Arrange: Retrieve the setup Tender Id
        Tender__c testTender = [SELECT Id FROM Tender__c LIMIT 1];

        // Act: Call the controller method
        Test.startTest();
        List<Bidders_Contact_Details__c> results = BidderContactController.getBidderContacts(testTender.Id);
        Test.stopTest();

        // Assert: Verify the correct number of records is returned
        System.assertEquals(2, results.size(), 'The method should return exactly 2 bidder contacts.');
        
        // Assert: Verify the data was retrieved correctly
        System.assertEquals('Alice Smith', results[0].Name, 'First contact name should match.');
        System.assertEquals('alice@example.com', results[0].Email__c, 'First contact email should match.');
    }

    @IsTest
    static void testGetBidderContacts_WithInvalidTender() {
        // Act: Call the controller method with a null Id
        Test.startTest();
        List<Bidders_Contact_Details__c> results = BidderContactController.getBidderContacts(null);
        Test.stopTest();

        // Assert: Verify that no records are returned
        System.assertEquals(0, results.size(), 'The method should return 0 records when a null Tender Id is passed.');
    }
}