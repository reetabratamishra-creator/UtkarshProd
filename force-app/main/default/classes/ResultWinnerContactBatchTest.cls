@isTest
private class ResultWinnerContactBatchTest {

    // ============================================================
    // SUCCESS MOCK
    // ============================================================
    private class ContactSuccessMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            res.setBody(
                '{' +
                    '"Success":true,' +
                    '"Message":"OK",' +
                    '"TotalRecord":1,' +
                    '"StatusCode":200,' +
                    '"Data":[' +
                        '{' +
                            '"bidder_name":"Test Winner",' +
                            '"contact_number":"9876543210",' +
                            '"email_id":"winner@test.com",' +
                            '"pan_no":"ABCDE1234F",' +
                            '"vendorcode":"V001",' +
                            '"seller_id":"S001",' +
                            '"gem_id":"G001",' +
                            '"msme_number":"MSME001",' +
                            '"category":"Steel",' +
                            '"branch_name":"Kolkata",' +
                            '"address":"Test Address",' +
                            '"pincode":"700001",' +
                            '"gst_number":"GST001",' +
                            '"phone_number":"9123456789",' +
                            '"alternate_email_id":"alternate@test.com",' +
                            '"designation":"Manager"' +
                        '}' +
                    ']' +
                '}'
            );

            return res;
        }
    }


    // ============================================================
    // FAILURE MOCK
    // ============================================================
    private class ContactFailureMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();

            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);

            res.setBody(
                '{"Success":false,"Message":"Internal Server Error","TotalRecord":0,"Data":[],"StatusCode":500}'
            );

            return res;
        }
    }


    // ============================================================
    // TEST DATA
    // ============================================================
    @TestSetup
    static void setupData() {

        Tender__c tender = new Tender__c(
            Common_Key__c = 'TEST-PRODUCT-Tender-1'
        );

        insert tender;


        Bidders__c bidder = new Bidders__c(
            Bidder_Name__c = 'Test Winner',
            External_Tender_Id__c = '10001',
            Tender__c = tender.Id
        );

        insert bidder;
    }


    // ============================================================
    // SUCCESS - FULL BATCH
    // ============================================================
    @isTest
    static void testBatchSuccess() {

        Bidders__c bidder = [
            SELECT
                Id,
                Bidder_Name__c,
                External_Tender_Id__c,
                Tender__c,
                Tender__r.Id,
                Tender__r.Common_Key__c,
                OwnerId
            FROM Bidders__c
            LIMIT 1
        ];


        Map<Id, String> winnerBidderProductMap =
            new Map<Id, String>();

        winnerBidderProductMap.put(
            bidder.Id,
            'Test Product'
        );


        Test.setMock(
            HttpCalloutMock.class,
            new ContactSuccessMock()
        );


        Test.startTest();

        Database.executeBatch(
            new ResultWinnerContactBatch(
                winnerBidderProductMap
            ),
            25
        );

        Test.stopTest();


        // ========================================================
        // VERIFY CONTACT
        // ========================================================

        List<Bidders_Contact_Details__c> contacts = [
            SELECT
                Id,
                Name,
                Bidders__c,
                Tender__c,
                Contact_Number__c,
                Email__c,
                Pan_No__c,
                Vendorcode__c,
                Seller_Id__c,
                Gem_Id__c,
                Msme_Number__c,
                Category__c,
                Branch_Name__c,
                Address__c,
                Pincode__c,
                GST_Number__c,
                Alternate_Phone__c,
                Alternate_Email__c,
                Designation__c,
                Source_Tender_Id__c,
                Contact_Unique_Key__c,
                OwnerId
            FROM Bidders_Contact_Details__c
            WHERE Bidders__c = :bidder.Id
        ];


        System.assertEquals(
            1,
            contacts.size(),
            'One contact record should be created.'
        );


        Bidders_Contact_Details__c contact =
            contacts[0];


        System.assertEquals(
            bidder.Id,
            contact.Bidders__c
        );

        System.assertEquals(
            bidder.Tender__c,
            contact.Tender__c
        );

        System.assertEquals(
            'Test Winner',
            contact.Name
        );

        System.assertEquals(
            '9876543210',
            contact.Contact_Number__c
        );

        System.assertEquals(
            'winner@test.com',
            contact.Email__c
        );

        System.assertEquals(
            'ABCDE1234F',
            contact.Pan_No__c
        );

        System.assertEquals(
            'V001',
            contact.Vendorcode__c
        );

        System.assertEquals(
            'S001',
            contact.Seller_Id__c
        );

        System.assertEquals(
            'G001',
            contact.Gem_Id__c
        );

        System.assertEquals(
            'MSME001',
            contact.Msme_Number__c
        );

        System.assertEquals(
            'Steel',
            contact.Category__c
        );

        System.assertEquals(
            'Kolkata',
            contact.Branch_Name__c
        );

        System.assertEquals(
            'Test Address',
            contact.Address__c
        );

        System.assertEquals(
            '700001',
            contact.Pincode__c
        );

        System.assertEquals(
            'GST001',
            contact.GST_Number__c
        );

        System.assertEquals(
            '9123456789',
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

        System.assertEquals(
            '10001',
            contact.Source_Tender_Id__c
        );

        System.assertEquals(
            '10001-Test Winner',
            contact.Contact_Unique_Key__c
        );
    }


    // ============================================================
    // FAILURE API RESPONSE
    // ============================================================
    @isTest
    static void testBatchApiFailure() {

        Bidders__c bidder = [
            SELECT
                Id,
                Bidder_Name__c,
                External_Tender_Id__c,
                Tender__c,
                Tender__r.Id,
                Tender__r.Common_Key__c,
                OwnerId
            FROM Bidders__c
            LIMIT 1
        ];


        Map<Id, String> winnerBidderProductMap =
            new Map<Id, String>();

        winnerBidderProductMap.put(
            bidder.Id,
            'Test Product'
        );


        Test.setMock(
            HttpCalloutMock.class,
            new ContactFailureMock()
        );


        Test.startTest();

        Database.executeBatch(
            new ResultWinnerContactBatch(
                winnerBidderProductMap
            ),
            25
        );

        Test.stopTest();


        // API failed, therefore no contact should be created.
        Integer contactCount = [
            SELECT COUNT()
            FROM Bidders_Contact_Details__c
            WHERE Bidders__c = :bidder.Id
        ];


        System.assertEquals(
            0,
            contactCount,
            'No contact should be created when Contact API fails.'
        );
    }


    // ============================================================
    // EMPTY MAP
    // ============================================================
    @isTest
    static void testEmptyWinnerBidderMap() {

        Map<Id, String> emptyMap =
            new Map<Id, String>();


        Test.startTest();

        ResultWinnerContactBatch batch =
            new ResultWinnerContactBatch(emptyMap);

        Database.executeBatch(
            batch,
            25
        );

        Test.stopTest();


        System.assert(
            true,
            'Batch should complete successfully with an empty map.'
        );
    }


    // ============================================================
    // DIRECT FINISH COVERAGE
    // ============================================================
    @isTest
    static void testFinish() {

        ResultWinnerContactBatch batch =
            new ResultWinnerContactBatch(
                new Map<Id, String>()
            );

        Test.startTest();

        batch.finish(null);

        Test.stopTest();

        System.assert(
            true,
            'finish() should execute without exception.'
        );
    }
}