@isTest
private class ExotelLeadHandlerTest {

    private static RestRequest createRequest(
        String fromNo,
        String toNo,
        String callSid,
        String callType,
        String dialCallStatus
    ) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ExotelLeadHandler/';
        req.httpMethod = 'GET';

        if (fromNo != null)
            req.params.put('From', fromNo);

        if (toNo != null)
            req.params.put('To', toNo);

        if (callSid != null)
            req.params.put('CallSid', callSid);

        // Changed from CallStatus to CallType
        if (callType != null)
            req.params.put('CallType', callType);

        if (dialCallStatus != null)
            req.params.put('DialCallStatus', dialCallStatus);

        return req;
    }

    @isTest
    static void testNewLeadAndTaskCreation() {

        RestContext.request = createRequest(
            '+919876543210',
            '+911234567890',
            'CA123456',
            'completed',
            'completed'
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        ExotelLeadHandler.handleCall();
        Test.stopTest();

        Lead ld = [
            SELECT Id, Phone, LeadSource
            FROM Lead
            WHERE Phone = '+919876543210'
            LIMIT 1
        ];

        System.assertEquals('INBOUND PHONE CALL', ld.LeadSource);

        Task t = [
            SELECT Subject,
                   Status,
                   CallType,
                   CallDisposition,
                   Exotel_CTI__Call_Sid__c,
                   Exotel_CTI__Call_Status__c,
                   Exotel_CTI__Call_Direction__c
            FROM Task
            WHERE Exotel_CTI__Call_Sid__c = 'CA123456'
            LIMIT 1
        ];

        System.assertEquals(
            'Inbound Call from +919876543210',
            t.Subject
        );
        System.assertEquals('Completed', t.Status);
        System.assertEquals('Inbound', t.CallType);
        System.assertEquals('completed', t.CallDisposition);
        System.assertEquals('CA123456', t.Exotel_CTI__Call_Sid__c);
        System.assertEquals('completed', t.Exotel_CTI__Call_Status__c);
        System.assertEquals('Inbound', t.Exotel_CTI__Call_Direction__c);

        System.assertEquals(200, RestContext.response.statusCode);
    }

    @isTest
    static void testExistingLeadCreatesTaskOnly() {

        Lead l = new Lead(
            LastName = 'Existing',
            Company = 'ABC Pvt Ltd',
            Phone = '+919999999999',
            Status = 'Prospect'
        );
        insert l;

        RestContext.request = createRequest(
            '+919999999999',
            '+911111111111',
            'CA999999',
            'completed',
            'completed'
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        ExotelLeadHandler.handleCall();
        Test.stopTest();

        Integer leadCount = [
            SELECT COUNT()
            FROM Lead
            WHERE Phone = '+919999999999'
        ];

        System.assertEquals(1, leadCount);

        Task t = [
            SELECT Subject,
                   WhoId,
                   Exotel_CTI__Call_Sid__c
            FROM Task
            WHERE Exotel_CTI__Call_Sid__c = 'CA999999'
            LIMIT 1
        ];

        System.assertEquals(l.Id, t.WhoId);
        System.assertEquals(
            'Inbound Call from +919999999999',
            t.Subject
        );
    }

    @isTest
    static void testMissedCall() {

        RestContext.request = createRequest(
            '+918888888888',
            '+917777777777',
            'CAMissed123',
            'missed',
            'no-answer'
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        ExotelLeadHandler.handleCall();
        Test.stopTest();

        Task t = [
            SELECT Subject,
                   Status,
                   CallDisposition,
                   Exotel_CTI__Call_Sid__c,
                   Exotel_CTI__Call_Status__c
            FROM Task
            WHERE Exotel_CTI__Call_Sid__c = 'CAMissed123'
            LIMIT 1
        ];

        System.assertEquals(
            'Missed Call from +918888888888',
            t.Subject
        );
        System.assertEquals('Completed', t.Status);
        System.assertEquals('no-answer', t.CallDisposition);
        System.assertEquals('missed', t.Exotel_CTI__Call_Status__c);
    }

    @isTest
    static void testBlankPhone() {

        RestContext.request = createRequest(
            '',
            '+911234567890',
            'CABlank',
            'completed',
            'completed'
        );
        RestContext.response = new RestResponse();

        Test.startTest();
        ExotelLeadHandler.handleCall();
        Test.stopTest();

        Task t = [
            SELECT Id,
                   Exotel_CTI__Call_Sid__c
            FROM Task
            WHERE Exotel_CTI__Call_Sid__c = 'CABlank'
            LIMIT 1
        ];

        System.assertNotEquals(null, t.Id);
        System.assertEquals(200, RestContext.response.statusCode);
    }
}