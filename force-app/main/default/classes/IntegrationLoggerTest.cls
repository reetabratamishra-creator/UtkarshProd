@isTest
private without sharing class IntegrationLoggerTest {

    @isTest
    static void testSimpleLogAndFlush() {
        Test.startTest();
        Integration_Log__c logRec = IntegrationLogger.log(
            'Count', 'Steel Pipes', 'tender-listing-data-count',
            '{"req":true}', '{"res":true}', 200, true, null
        );
        System.assertNotEquals(null, logRec, 'log() should return the queued record.');
        IntegrationLogger.flush();
        Test.stopTest();

        List<Integration_Log__c> inserted = [SELECT Id, Stage__c, Status__c
                                              FROM Integration_Log__c WHERE Stage__c = 'Count'];
        System.assertEquals(1, inserted.size());
        System.assertEquals('Success', inserted[0].Status__c);
    }

    @isTest
    static void testOverloadWithTenderIdAndCommonKey() {
        IntegrationLogger.log(
            'ProbableBidder', 'Steel Pipes', 'probable-bidders-tenderIdWise',
            '{"req":true}', '{"res":true}', 200, true, null,
            null, 'Steel Pipes-10082026-111111-Tender-1'
        );
        IntegrationLogger.flush();

        List<Integration_Log__c> inserted = [SELECT Id, Common_Key__c FROM Integration_Log__c
                                              WHERE Stage__c = 'ProbableBidder'];
        System.assertEquals(1, inserted.size());
        System.assertEquals('Steel Pipes-10082026-111111-Tender-1', inserted[0].Common_Key__c);
    }

    @isTest
    static void testOverloadWithMailType() {
        IntegrationLogger.log(
            'TenderCreated', 'Steel Pipes', 'tender-listing-data (tender-created)',
            null, 'External_Tender_Id=1001', null, true, null,
            null, 'Steel Pipes-10082026-111111-Tender-1', 1
        );
        IntegrationLogger.flush();

        Integration_Log__c inserted = [SELECT Id, MailType__c FROM Integration_Log__c
                                        WHERE Stage__c = 'TenderCreated' LIMIT 1];
        System.assertEquals(1, inserted.MailType__c);
    }

    @isTest
    static void testFailedLogSetsStatusFailed() {
        IntegrationLogger.log(
            'ListingPageFailed', 'Steel Pipes', 'tender-listing-data (page 1)',
            '{"req":true}', 'EXCEPTION: timeout', null, false, 'EXCEPTION: timeout'
        );
        IntegrationLogger.flush();

        Integration_Log__c inserted = [SELECT Id, Status__c, Is_Success__c, Error_Message__c
                                        FROM Integration_Log__c WHERE Stage__c = 'ListingPageFailed' LIMIT 1];
        System.assertEquals('Failed', inserted.Status__c);
        System.assertEquals(false, inserted.Is_Success__c);
        System.assertEquals('EXCEPTION: timeout', inserted.Error_Message__c);
    }

    @isTest
    static void testLargeResponseIsChunkedIntoChildRecords() {
        // Just over 131072 chars - forces exactly 2 chunks.
        String bigBody = ''.rightPad(140000, 'x');
        IntegrationLogger.log(
            'Listing', 'Steel Pipes', 'tender-listing-data (page 1)',
            '{"req":true}', bigBody, 200, true, null
        );
        IntegrationLogger.flush();

        Integration_Log__c parent = [SELECT Id, Response_Body__c FROM Integration_Log__c
                                      WHERE Stage__c = 'Listing' LIMIT 1];
        System.assert(parent.Response_Body__c.length() <= 5000, 'Parent preview must be truncated.');

        List<Integration_JSON_Log__c> children = [SELECT Id, Sequence__c, JSON_Details__c
                                                    FROM Integration_JSON_Log__c
                                                    WHERE Integration_Log__c = :parent.Id
                                                    ORDER BY Sequence__c];
        System.assertEquals(2, children.size(), 'A >131072 char body should be split into 2 chunks.');
        System.assertEquals(1, children[0].Sequence__c);
        System.assertEquals(2, children[1].Sequence__c);
        System.assertEquals(131072, children[0].JSON_Details__c.length());
    }

    @isTest
    static void testFlushWithNoPendingEntriesDoesNothing() {
        Test.startTest();
        IntegrationLogger.flush(); // nothing queued
        Test.stopTest();

        List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];
        System.assertEquals(0, logs.size());
    }

    @isTest
    static void testNullResponseBodyCreatesNoChildren() {
        IntegrationLogger.log(
            'Count', 'Steel Pipes', 'tender-listing-data-count',
            '{"req":true}', null, null, false, 'no response'
        );
        IntegrationLogger.flush();

        Integration_Log__c parent = [SELECT Id FROM Integration_Log__c WHERE Stage__c = 'Count' LIMIT 1];
        List<Integration_JSON_Log__c> children = [SELECT Id FROM Integration_JSON_Log__c
                                                    WHERE Integration_Log__c = :parent.Id];
        System.assertEquals(0, children.size());
    }
}