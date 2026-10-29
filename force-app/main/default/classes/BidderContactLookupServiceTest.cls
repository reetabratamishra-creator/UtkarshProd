@IsTest
private class BidderContactLookupServiceTest {

/*
 * ---------------------------------------------------------
 * HTTP MOCK - SUCCESS
 * ---------------------------------------------------------
 */
private class SuccessMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest req) {

        System.assertEquals(
            'POST',
            req.getMethod(),
            'API method should be POST'
        );

        System.assert(
            req.getEndpoint().contains(
                '/Utkarsh/api/probable-bidders-contact-details'
            ),
            'Incorrect endpoint'
        );

        System.assert(
            req.getBody().contains('ProbableBidderName'),
            'Request body should contain ProbableBidderName'
        );

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');

        res.setBody(
            '{' +
                '"Success":true,' +
                '"Data":[' +
                    '{' +
                        '"bidder_name":"ABC Industries",' +
                        '"contact_number":"9876543210",' +
                        '"email_id":"abc@test.com",' +
                        '"pan_no":"ABCDE1234F",' +
                        '"vendorcode":"VEN001",' +
                        '"seller_id":"SELL001",' +
                        '"gem_id":"GEM001",' +
                        '"msme_number":"MSME001",' +
                        '"category":"Manufacturer",' +
                        '"branch_name":"Kolkata",' +
                        '"address":"Kolkata, West Bengal",' +
                        '"pincode":"700001",' +
                        '"gst_number":"19ABCDE1234F1Z5",' +
                        '"phone_number":"03312345678",' +
                        '"alternate_email_id":"alternate@test.com",' +
                        '"designation":"Manager"' +
                    '}' +
                ']' +
            '}'
        );

        return res;
    }
}


/*
 * ---------------------------------------------------------
 * HTTP MOCK - SUCCESS BUT NO DATA
 * ---------------------------------------------------------
 */
private class EmptyDataMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest req) {

        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');

        res.setBody(
            '{"Success":true,"Data":[]}'
        );

        return res;
    }
}


/*
 * ---------------------------------------------------------
 * HTTP MOCK - API ERROR
 * ---------------------------------------------------------
 */
private class ErrorMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest req) {

        HttpResponse res = new HttpResponse();
        res.setStatusCode(500);
        res.setHeader('Content-Type', 'application/json');

        res.setBody(
            '{"Success":false,"Message":"Internal Server Error"}'
        );

        return res;
    }
}


/*
 * ---------------------------------------------------------
 * HTTP MOCK - EXCEPTION
 * ---------------------------------------------------------
 */
private class ExceptionMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest req) {

        throw new CalloutException(
            'Mock callout exception'
        );
    }
}


/*
 * ---------------------------------------------------------
 * TEST DATA
 * ---------------------------------------------------------
 */
@TestSetup
static void setupData() {

    Bidders__c bidder = new Bidders__c();

    bidder.Bidder_Name__c = 'ABC Industries';

    insert bidder;
}


/*
 * ---------------------------------------------------------
 * TEST 1
 *
 * fetchContactDetails()
 *
 * Successful API call
 *
 * Also verifies REPLACE LOGIC
 * ---------------------------------------------------------
 */
@IsTest
static void testFetchContactDetailsSuccessAndReplace() {

    Bidders__c bidder = [
        SELECT Id,
               Bidder_Name__c,
               Tender__c,
               External_Tender_Id__c,
               OwnerId
        FROM Bidders__c
        LIMIT 1
    ];

    /*
     * Create an existing contact record.
     *
     * The production code should delete this record
     * and create a fresh one.
     */
    Bidders_Contact_Details__c oldContact =
        new Bidders_Contact_Details__c();

    oldContact.Bidders__c = bidder.Id;
    oldContact.Name = 'Old Contact';

    insert oldContact;

    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );

    Test.startTest();

    String result =
        BidderContactLookupService.fetchContactDetails(
            bidder.Id
        );

    Test.stopTest();

    /*
     * Verify returned message.
     */
    System.assert(
        result.contains('Contact details fetched and saved'),
        'Success message was not returned'
    );

    /*
     * Verify only one contact exists.
     */
    List<Bidders_Contact_Details__c> contacts = [
        SELECT Id,
               Name,
               Bidders__c,
               Contact_Number__c,
               Email__c,
               PAN_No__c,
               Vendorcode__c,
               Seller_Id__c,
               Gem_Id__c,
               Msme_Number__c,
               Category__c,
               Branch_Name__c,
               Address__c,
               Pincode__c,
               Gst_Number__c,
               Alternate_Phone__c,
               Alternate_Email__c,
               Designation__c
        FROM Bidders_Contact_Details__c
        WHERE Bidders__c = :bidder.Id
    ];

    System.assertEquals(
        1,
        contacts.size(),
        'Existing contact should be replaced, not duplicated'
    );

    Bidders_Contact_Details__c contact = contacts[0];

    System.assertEquals(
        'ABC Industries',
        contact.Name
    );

    System.assertEquals(
        bidder.Id,
        contact.Bidders__c
    );

    System.assertEquals(
        '9876543210',
        contact.Contact_Number__c
    );

    System.assertEquals(
        'abc@test.com',
        contact.Email__c
    );

    System.assertEquals(
        'ABCDE1234F',
        contact.PAN_No__c
    );

    System.assertEquals(
        'VEN001',
        contact.Vendorcode__c
    );

    System.assertEquals(
        'SELL001',
        contact.Seller_Id__c
    );

    System.assertEquals(
        'GEM001',
        contact.Gem_Id__c
    );

    System.assertEquals(
        'MSME001',
        contact.Msme_Number__c
    );

    System.assertEquals(
        'Manufacturer',
        contact.Category__c
    );

    System.assertEquals(
        'Kolkata',
        contact.Branch_Name__c
    );

    System.assertEquals(
        'Kolkata, West Bengal',
        contact.Address__c
    );

    System.assertEquals(
        '700001',
        contact.Pincode__c
    );

    System.assertEquals(
        '19ABCDE1234F1Z5',
        contact.Gst_Number__c
    );

    System.assertEquals(
        '03312345678',
        contact.Alternate_Phone__c
    );

    System.assertEquals(
        'alternate@test.com',
        contact.Alternate_Email__c
    );

    System.assertEquals(
        'Manager',
        contact.Designation__c
    );
}


/*
 * ---------------------------------------------------------
 * TEST 2
 *
 * Bidder Id does not exist
 * ---------------------------------------------------------
 */
@IsTest
static void testFetchContactDetailsBidderNotFound() {

    Id fakeBidderId =
        'a02000000000001AAA';

    Test.startTest();

    String result =
        BidderContactLookupService.fetchContactDetails(
            fakeBidderId
        );

    Test.stopTest();

    System.assert(
        result.contains('Bidder record not found'),
        'Expected bidder-not-found message'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 3
 *
 * Bidder has blank name
 * ---------------------------------------------------------
 */
@IsTest
static void testFetchContactDetailsBlankName() {

    Bidders__c bidder = new Bidders__c();

    bidder.Bidder_Name__c = null;

    insert bidder;

    Test.startTest();

    String result =
        BidderContactLookupService.fetchContactDetails(
            bidder.Id
        );

    Test.stopTest();

    System.assert(
        result.contains('no name stored'),
        'Expected blank-name message'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 4
 *
 * API returns 200 but no contact data
 * ---------------------------------------------------------
 */
@IsTest
static void testFetchContactDetailsNoData() {

    Bidders__c bidder = [
        SELECT Id
        FROM Bidders__c
        LIMIT 1
    ];

    Test.setMock(
        HttpCalloutMock.class,
        new EmptyDataMock()
    );

    Test.startTest();

    String result =
        BidderContactLookupService.fetchContactDetails(
            bidder.Id
        );

    Test.stopTest();

    System.assert(
        result.contains('No contact details were returned'),
        'Expected no-contact-details message'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 5
 *
 * API returns non-200 response
 * ---------------------------------------------------------
 */
@IsTest
static void testFetchContactDetailsApiError() {

    Bidders__c bidder = [
        SELECT Id
        FROM Bidders__c
        LIMIT 1
    ];

    Test.setMock(
        HttpCalloutMock.class,
        new ErrorMock()
    );

    Test.startTest();

    String result =
        BidderContactLookupService.fetchContactDetails(
            bidder.Id
        );

    Test.stopTest();

    System.assert(
        result.contains('No contact details were returned'),
        'Expected API error to result in no-contact message'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 6
 *
 * API throws exception
 * ---------------------------------------------------------
 */
@IsTest
static void testFetchContactDetailsException() {

    Bidders__c bidder = [
        SELECT Id
        FROM Bidders__c
        LIMIT 1
    ];

    Test.setMock(
        HttpCalloutMock.class,
        new ExceptionMock()
    );

    Test.startTest();

    String result =
        BidderContactLookupService.fetchContactDetails(
            bidder.Id
        );

    Test.stopTest();

    System.assert(
        result.contains('No contact details were returned'),
        'Expected exception to be handled gracefully'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 7
 *
 * runForBidderName(String bidderName)
 * ---------------------------------------------------------
 */
@IsTest
static void testRunForBidderName() {

    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );

    Test.startTest();

    BidderContactLookupService.runForBidderName(
        'ABC Industries'
    );

    Test.stopTest();

    List<Bidders_Contact_Details__c> contacts = [
        SELECT Id,
               Name
        FROM Bidders_Contact_Details__c
        WHERE Name = 'ABC Industries'
    ];

    System.assertEquals(
        1,
        contacts.size(),
        'Contact should be inserted'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 8
 *
 * runForBidderName(bidderName, tenderId)
 *
 * Matching bidder found
 * ---------------------------------------------------------
 */
@IsTest
static void testRunForBidderNameWithTender() {

    Bidders__c bidder = [
        SELECT Id,
               Tender__c,
               OwnerId
        FROM Bidders__c
        LIMIT 1
    ];

    String tenderId = 'TENDER001';

    bidder.Bidder_Unique_Key__c =
        tenderId + '-ABC Industries';

    // Record already exists because of @TestSetup
    update bidder;

    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );

    Test.startTest();

    BidderContactLookupService.runForBidderName(
        'ABC Industries',
        tenderId
    );

    Test.stopTest();

    List<Bidders_Contact_Details__c> contacts = [
        SELECT Id,
               Name,
               Bidders__c,
               Contact_Unique_Key__c,
               Source_Tender_Id__c
        FROM Bidders_Contact_Details__c
        WHERE Contact_Unique_Key__c =
            :tenderId + '-ABC Industries'
    ];

    System.assertEquals(
        1,
        contacts.size(),
        'Contact should be created'
    );

    System.assertEquals(
        bidder.Id,
        contacts[0].Bidders__c
    );

    System.assertEquals(
        tenderId,
        contacts[0].Source_Tender_Id__c
    );

    System.assertEquals(
        tenderId + '-ABC Industries',
        contacts[0].Contact_Unique_Key__c
    );
}
/*
 * ---------------------------------------------------------
 * TEST 9
 *
 * runForBidderName(bidderName, tenderId)
 *
 * No matching bidder found
 * ---------------------------------------------------------
 */
@IsTest
static void testRunForBidderNameWithTenderNoMatch() {

    Test.setMock(
        HttpCalloutMock.class,
        new SuccessMock()
    );

    Test.startTest();

    BidderContactLookupService.runForBidderName(
        'ABC Industries',
        'TENDER-NOT-FOUND'
    );

    Test.stopTest();

    List<Bidders_Contact_Details__c> contacts = [
        SELECT Id,
               Name,
               Bidders__c,
               Contact_Unique_Key__c,
               Source_Tender_Id__c
        FROM Bidders_Contact_Details__c
        WHERE Contact_Unique_Key__c =
            'TENDER-NOT-FOUND-ABC Industries'
    ];

    System.assertEquals(
        1,
        contacts.size(),
        'Contact should still be inserted'
    );

    System.assertEquals(
        null,
        contacts[0].Bidders__c,
        'No matching bidder should mean no Bidders__c link'
    );

    System.assertEquals(
        'TENDER-NOT-FOUND',
        contacts[0].Source_Tender_Id__c
    );
}


/*
 * ---------------------------------------------------------
 * TEST 10
 *
 * runForBidderName() with blank bidder name
 * ---------------------------------------------------------
 */
@IsTest
static void testRunForBidderNameBlank() {

    Test.startTest();

    BidderContactLookupService.runForBidderName(
        ''
    );

    BidderContactLookupService.runForBidderName(
        null
    );

    BidderContactLookupService.runForBidderName(
        '   '
    );

    Test.stopTest();

    System.assert(
        true,
        'Blank bidder name should be handled without exception'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 11
 *
 * runForBidderName with tender + API returns no data
 * ---------------------------------------------------------
 */
@IsTest
static void testRunForBidderNameNoContactData() {

    Test.setMock(
        HttpCalloutMock.class,
        new EmptyDataMock()
    );

    Test.startTest();

    BidderContactLookupService.runForBidderName(
        'ABC Industries',
        'TENDER002'
    );

    Test.stopTest();

    System.assertEquals(
        0,
        [
            SELECT COUNT()
            FROM Bidders_Contact_Details__c
            WHERE Contact_Unique_Key__c =
                'TENDER002-ABC Industries'
        ],
        'No contact should be inserted when API returns no data'
    );
}


/*
 * ---------------------------------------------------------
 * TEST 12
 *
 * runForBidderName with API exception
 * ---------------------------------------------------------
 */
@IsTest
static void testRunForBidderNameException() {

    Test.setMock(
        HttpCalloutMock.class,
        new ExceptionMock()
    );

    Test.startTest();

    BidderContactLookupService.runForBidderName(
        'ABC Industries',
        'TENDER003'
    );

    Test.stopTest();

    System.assertEquals(
        0,
        [
            SELECT COUNT()
            FROM Bidders_Contact_Details__c
            WHERE Contact_Unique_Key__c =
                'TENDER003-ABC Industries'
        ],
        'No contact should be inserted when API throws exception'
    );
}

}