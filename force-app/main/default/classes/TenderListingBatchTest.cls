@isTest
private without sharing class TenderListingBatchTest {

    private static Integer getProductCount() {
        return [
            SELECT COUNT()
            FROM Tender_Product_Mapping__mdt
        ];
    }

    private class TenderListingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            if (req.getEndpoint().contains('tender-listing-data-count')) {
                res.setBody(
                    '{"Success":true,"Message":"OK","TotalRecord":1,' +
                    '"Data":[{"count":2}],"StatusCode":200}'
                );
            } else if (req.getEndpoint().contains('tender-listing-data')) {
                res.setBody(buildListingResponse());
            } else {
                res.setStatusCode(404);
                res.setBody('{}');
            }
            return res;
        }

        private String buildListingResponse() {
            return '{'
                + '"Success":true,"Message":"OK","TotalRecord":2,"StatusCode":200,'
                + '"Data":['
                + '{'
                    + '"tenderid":1001,'
                    + '"sourcetenderid":"SRC-1001",'
                    + '"value":1000.5,'
                    + '"biddeadline":"2026-09-01",'
                    + '"emd":10.0,'
                    + '"documentcost":5.0,'
                    + '"authority":"Test Authority",'
                    + '"currency":"INR",'
                    + '"tenderdetails":"Details 1",'
                    + '"tenderdescription":"Description 1",'
                    + '"prebidmeetingdate":"2026-08-15",'
                    + '"datecreated":"2026-08-01",'
                    + '"corrigenduminfo":"false",'
                    + '"sector":["Steel"],'
                    + '"sourceurl":"http://example.com/1",'
                    + '"isupdated":false,'
                    + '"subindustry":["Pipes"],'
                    + '"completionofwork":"6 months",'
                    + '"ai_summary":"Summary 1",'
                    + '"location":['
                        + '{"tenderid":1001,"country":"India","state":"WB","city":"Kolkata"}'
                    + '],'
                    + '"documents":['
                        + '{'
                            + '"documentid":1,'
                            + '"name":"Doc1",'
                            + '"downloadLink":"http://example.com/doc1",'
                            + '"type":"pdf"'
                        + '}'
                    + '],'
                    + '"zipdocumentdownload":"http://example.com/zip1"'
                + '},'
                + '{'
                    + '"tenderid":1002,'
                    + '"sourcetenderid":"SRC-1002",'
                    + '"value":2000.5,'
                    + '"biddeadline":"2026-09-05",'
                    + '"emd":20.0,'
                    + '"documentcost":8.0,'
                    + '"authority":"Test Authority 2",'
                    + '"currency":"USD",'
                    + '"tenderdetails":"Details 2",'
                    + '"tenderdescription":"Description 2",'
                    + '"prebidmeetingdate":"2026-08-20",'
                    + '"datecreated":"2026-08-02",'
                    + '"corrigenduminfo":"false",'
                    + '"sector":["HDPE"],'
                    + '"sourceurl":"http://example.com/2",'
                    + '"isupdated":false,'
                    + '"subindustry":["Polymer"],'
                    + '"completionofwork":"3 months",'
                    + '"ai_summary":"Summary 2",'
                    + '"location":['
                        + '{"tenderid":1002,"country":"India","state":"MH","city":"Mumbai"}'
                    + '],'
                    + '"documents":[],'
                    + '"zipdocumentdownload":null'
                + '}'
                + ']'
            + '}';
        }
    }

    private class ZeroCountMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"Success":true,"Message":"OK","TotalRecord":0,' +
                '"Data":[{"count":0}],"StatusCode":200}'
            );
            return res;
        }
    }

    @isTest
    static void testBatchCreatesNewTenders() {
        Integer productCount = getProductCount();
        if (productCount == 0) {
            return;
        }

        Test.setMock(HttpCalloutMock.class, new TenderListingMock());

        Test.startTest();
        Database.executeBatch(new TenderListingBatch(1), productCount);
        Test.stopTest();

        List<Tender__c> created = [
            SELECT Id, External_Tender_Id__c, Common_Key__c, Base_Common_Key__c,
                   Corrigendum_Info__c, MailType__c
            FROM Tender__c
            WHERE External_Tender_Id__c IN ('1001', '1002')
        ];

        System.assertEquals(2, created.size(), 'Both tenders from the mock listing response should be upserted.');

        for (Tender__c t : created) {
            System.assert(t.Common_Key__c.contains('-Tender-'), 'New tenders should get a Tender-N common key.');
            System.assertEquals(1, t.MailType__c, 'MailType should be stamped from the batch constructor.');
        }

        List<Integration_Log__c> logs = [SELECT Id, Stage__c FROM Integration_Log__c];
        System.assert(!logs.isEmpty(), 'Integration logs should be written.');
    }

    @isTest
    static void testCorrigendumSkipLogic() {
        Integer productCount = getProductCount();
        if (productCount == 0) {
            return;
        }

        Tender__c existing = new Tender__c(
            External_Tender_Id__c = '1001',
            Common_Key__c = 'PreExisting-Tender-1',
            Base_Common_Key__c = 'PreExisting',
            Corrigendum_Info__c = false
        );

        insert as system existing;

        Test.setMock(HttpCalloutMock.class, new TenderListingMock());

        Test.startTest();
        Database.executeBatch(new TenderListingBatch(2), productCount);
        Test.stopTest();

        Tender__c reQueried = [SELECT Id, Common_Key__c FROM Tender__c WHERE Id = :existing.Id];

        System.assertEquals(
            'PreExisting-Tender-1',
            reQueried.Common_Key__c,
            'Existing tender with no corrigendum should be skipped.'
        );

        List<Tender__c> newOnes = [SELECT Id FROM Tender__c WHERE External_Tender_Id__c = '1002'];
        System.assertEquals(1, newOnes.size(), 'Tender 1002 should be created.');
    }

    @isTest
    static void testZeroCountProductIsSkippedGracefully() {
        Integer productCount = getProductCount();
        if (productCount == 0) {
            return;
        }

        Test.setMock(HttpCalloutMock.class, new ZeroCountMock());

        Test.startTest();
        Database.executeBatch(new TenderListingBatch(1), productCount);
        Test.stopTest();

        List<Tender__c> created = [SELECT Id FROM Tender__c];
        System.assertEquals(0, created.size(), 'Zero-count product should create no tenders.');
    }

    @isTest
    static void testDefaultConstructorDoesNotThrow() {
        TenderListingBatch batch = new TenderListingBatch();
        System.assertNotEquals(null, batch, 'Default constructor should succeed.');
    }
}