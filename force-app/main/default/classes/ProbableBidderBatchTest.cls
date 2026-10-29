@isTest
private without sharing class ProbableBidderBatchTest {

    private class ProbableBidderMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"Success":true,"Message":"OK","TotalRecord":1,"StatusCode":200,'
                + '"Data":[{"tenderid":5001,"probable_bidder":["Acme Corp","Beta Industries","Acme Corp"]}]}');
            return res;
        }
    }

    private class FailedBidderMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"Success":false,"Message":"Server Error"}');
            return res;
        }
    }

    @isTest
    static void testCreatesBiddersAndDedupesWithinResponse() {
        Tender__c t = new Tender__c(
            External_Tender_Id__c = '5001',
            Common_Key__c = 'Steel Pipes-10082026-111111-Tender-1',
            Product_Name__c = 'Steel Pipes'
        );
        insert as system t;

        Map<Id, String> tenderProductMap = new Map<Id, String>{ t.Id => 'Steel Pipes' };
        Test.setMock(HttpCalloutMock.class, new ProbableBidderMock());

        Test.startTest();
        Database.executeBatch(new ProbableBidderBatch(tenderProductMap), 10);
        Test.stopTest();

        List<Bidders__c> bidders = [SELECT Id, Bidder_Name__c, Common_Key__c
                                     FROM Bidders__c WHERE Tender__c = :t.Id];
        // "Acme Corp" appears twice in the mock response - must collapse to one record.
        System.assertEquals(2, bidders.size(), 'Duplicate bidder names within one response must be deduped.');

        Set<String> names = new Set<String>();
        for (Bidders__c b : bidders) {
            names.add(b.Bidder_Name__c);
            System.assert(b.Common_Key__c.startsWith(t.Common_Key__c + '-Bidder-'),
                'Bidder Common_Key__c should be built off the tender Common_Key__c.');
        }
        System.assert(names.contains('Acme Corp'));
        System.assert(names.contains('Beta Industries'));
    }

    @isTest
    static void testRerunDoesNotDuplicateExistingBidders() {
        Tender__c t = new Tender__c(
            External_Tender_Id__c = '5001',
            Common_Key__c = 'Steel Pipes-10082026-111111-Tender-1',
            Product_Name__c = 'Steel Pipes'
        );
        insert as system t;

        Bidders__c existingBidder = new Bidders__c(
            Name = 'Acme Corp',
            Bidder_Name__c = 'Acme Corp',
            Tender__c = t.Id,
            Product_Name__c = 'Steel Pipes',
            Common_Key__c = t.Common_Key__c + '-Bidder-1',
            External_Tender_Id__c = '5001',
            Bidder_Unique_Key__c = '5001-Acme Corp'
        );
        insert as system existingBidder;

        Map<Id, String> tenderProductMap = new Map<Id, String>{ t.Id => 'Steel Pipes' };
        Test.setMock(HttpCalloutMock.class, new ProbableBidderMock());

        Test.startTest();
        Database.executeBatch(new ProbableBidderBatch(tenderProductMap), 10);
        Test.stopTest();

        List<Bidders__c> bidders = [SELECT Id, Bidder_Name__c FROM Bidders__c WHERE Tender__c = :t.Id];
        // Only "Beta Industries" should be newly added; "Acme Corp" already existed.
        System.assertEquals(2, bidders.size(), 'Existing bidder should not be duplicated; only the new one is added.');
    }

    @isTest
    static void testFailedCalloutLogsAndCreatesNoBidders() {
        Tender__c t = new Tender__c(
            External_Tender_Id__c = '5002',
            Common_Key__c = 'Steel Pipes-10082026-222222-Tender-1',
            Product_Name__c = 'Steel Pipes'
        );
        insert as system t;

        Map<Id, String> tenderProductMap = new Map<Id, String>{ t.Id => 'Steel Pipes' };
        Test.setMock(HttpCalloutMock.class, new FailedBidderMock());

        Test.startTest();
        Database.executeBatch(new ProbableBidderBatch(tenderProductMap), 10);
        Test.stopTest();

        List<Bidders__c> bidders = [SELECT Id FROM Bidders__c WHERE Tender__c = :t.Id];
        System.assertEquals(0, bidders.size(), 'No bidders should be created when the callout fails.');

        List<Integration_Log__c> logs = [SELECT Id, Is_Success__c FROM Integration_Log__c WHERE Tender__c = :t.Id];
        System.assert(!logs.isEmpty());
        System.assertEquals(false, logs[0].Is_Success__c);
    }
}