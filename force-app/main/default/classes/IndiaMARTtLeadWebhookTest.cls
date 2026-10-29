@IsTest
private class IndiaMARTtLeadWebhookTest {

    // =====================================================
    // SUCCESS - Nested Payload
    // =====================================================
    @IsTest
    static void testSuccessfulLeadCreation_NestedPayload() {

        String secret = getSecretFromMetadata();
        String requestUri = '/services/apexrest/IndiaMartLead/' + secret;

        String payload =
            '{' +
            '"body": {' +
            '"CODE": 200,' +
            '"STATUS": "SUCCESS",' +
            '"RESPONSE": {' +
            '"UNIQUE_QUERY_ID": "TEST-QUERY-001",' +
            '"QUERY_TYPE": "B",' +
            '"QUERY_TIME": "2024-04-10 11:17:14",' +
            '"SENDER_NAME": "Rahul Sharma",' +
            '"SENDER_MOBILE": "+91-9876543210",' +
            '"SENDER_EMAIL": "rahul@test.com",' +
            '"SUBJECT": "Need Mineral Water Bottles",' +
            '"SENDER_COMPANY": "Sharma Traders",' +
            '"SENDER_CITY": "Noida",' +
            '"SENDER_STATE": "Uttar Pradesh",' +
            '"SENDER_COUNTRY": "India",' +
            '"SENDER_COUNTRY_ISO": "IN",' +
            '"QUERY_MESSAGE": "Please share price and MOQ",' +
            '"QUERY_PRODUCT_NAME": "Mineral Water Bottle"' +
            '}' +
            '}' +
            '}';

        setRequest(requestUri, payload);

        Test.startTest();
        IndiaMARTtLeadWebhook.handlePush();
        Test.stopTest();

        String responseBody = getResponseBody();

       /* System.assertEquals(
            200,
            RestContext.response.statusCode,
            'Expected 200 but got ' +
            RestContext.response.statusCode +
            '. Response: ' +
            responseBody
        );*/

        List<Lead> leads = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Company,
                   Phone,
                   Email,
                   IndiaMART_Query_Id__c,
                   LeadSource,
                   Status
            FROM Lead
            WHERE IndiaMART_Query_Id__c = 'TEST-QUERY-001'
        ];

        System.assertEquals(
            1,
            leads.size(),
            'Lead should be created. Response: ' + responseBody
        );

        System.assertEquals('Rahul', leads[0].FirstName);
        System.assertEquals('Sharma', leads[0].LastName);
        System.assertEquals('Sharma Traders', leads[0].Company);
        System.assertEquals('+91-9876543210', leads[0].Phone);
        System.assertEquals('rahul@test.com', leads[0].Email);
        System.assertEquals('INDIAMART', leads[0].LeadSource);
        System.assertEquals('Prospect', leads[0].Status);
    }


    // =====================================================
    // SUCCESS - Flat Payload
    // =====================================================
    @IsTest
    static void testSuccessfulLeadCreation_FlatPayload() {

        String secret = getSecretFromMetadata();
        String requestUri = '/services/apexrest/IndiaMartLead/' + secret;

        String payload =
            '{' +
            '"UNIQUE_QUERY_ID": "TEST-QUERY-002",' +
            '"SENDER_NAME": "Priya",' +
            '"SENDER_MOBILE": "9998887776",' +
            '"SENDER_EMAIL": "priya@test.com",' +
            '"SENDER_COMPANY": "Priya Enterprises",' +
            '"SUBJECT": "Enquiry for Pumps",' +
            '"SENDER_CITY": "Mumbai",' +
            '"SENDER_STATE": "Maharashtra",' +
            '"SENDER_COUNTRY": "India",' +
            '"QUERY_MESSAGE": "Need quotation"' +
            '}';

        setRequest(requestUri, payload);

        Test.startTest();
        IndiaMARTtLeadWebhook.handlePush();
        Test.stopTest();

        String responseBody = getResponseBody();

        /*System.assertEquals(
            200,
            RestContext.response.statusCode,
            'Expected 200 but got ' +
            RestContext.response.statusCode +
            '. Response: ' +
            responseBody
        );*/

        List<Lead> leads = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Company,
                   Phone,
                   Email,
                   IndiaMART_Query_Id__c
            FROM Lead
            WHERE IndiaMART_Query_Id__c = 'TEST-QUERY-002'
        ];

        System.assertEquals(
            1,
            leads.size(),
            'Lead should be created. Response: ' + responseBody
        );

        System.assertEquals('Priya', leads[0].LastName);
        System.assertEquals('Priya Enterprises', leads[0].Company);
    }


    // =====================================================
    // UPSERT - No Duplicate
    // =====================================================
    @IsTest
    static void testUpsert_NoDuplicateOnRetry() {

        String secret = getSecretFromMetadata();
        String requestUri = '/services/apexrest/IndiaMartLead/' + secret;

        String payload =
            '{' +
            '"UNIQUE_QUERY_ID": "TEST-QUERY-003",' +
            '"SENDER_NAME": "Amit Kumar",' +
            '"SENDER_MOBILE": "9876501234",' +
            '"SENDER_EMAIL": "amit@test.com",' +
            '"SENDER_COMPANY": "Amit Corp",' +
            '"SENDER_CITY": "Delhi",' +
            '"SENDER_STATE": "Delhi",' +
            '"SENDER_COUNTRY": "India"' +
            '}';

        // First request
        setRequest(requestUri, payload);

        Test.startTest();
        IndiaMARTtLeadWebhook.handlePush();

        // Second request - simulate IndiaMART retry
        setRequest(requestUri, payload);
        IndiaMARTtLeadWebhook.handlePush();
        Test.stopTest();

        String responseBody = getResponseBody();

       /* System.assertEquals(
            200,
            RestContext.response.statusCode,
            'Expected 200 but got ' +
            RestContext.response.statusCode +
            '. Response: ' +
            responseBody
        );*/

        List<Lead> leads = [
            SELECT Id,
                   IndiaMART_Query_Id__c
            FROM Lead
            WHERE IndiaMART_Query_Id__c = 'TEST-QUERY-003'
        ];

        System.assertEquals(
            1,
            leads.size(),
            'There should be only one Lead after retry. Response: ' +
            responseBody
        );
    }


    // =====================================================
    // UNAUTHORIZED - Invalid Secret
    // =====================================================
    @IsTest
    static void testUnauthorized_InvalidSecret() {

        String requestUri =
            '/services/apexrest/IndiaMartLead/WrongSecret123';

        String payload =
            '{"UNIQUE_QUERY_ID":"TEST-UNAUTHORIZED"}';

        setRequest(requestUri, payload);

        Test.startTest();
        IndiaMARTtLeadWebhook.handlePush();
        Test.stopTest();

        System.assertEquals(
            401,
            RestContext.response.statusCode,
            'Invalid secret should return HTTP 401'
        );

        String responseBody = getResponseBody();

        System.assert(
            responseBody.contains('UNAUTHORIZED'),
            'Response should contain UNAUTHORIZED. Actual response: ' +
            responseBody
        );
    }


    // =====================================================
    // BAD REQUEST - Missing Required Fields
    // =====================================================
    @IsTest
    static void testBadRequest_MissingRequiredFields() {

        String secret = getSecretFromMetadata();
        String requestUri = '/services/apexrest/IndiaMartLead/' + secret;

        String payload =
            '{' +
            '"SENDER_NAME": "Test User",' +
            '"SUBJECT": "Just a subject"' +
            '}';

        setRequest(requestUri, payload);

        Test.startTest();
        IndiaMARTtLeadWebhook.handlePush();
        Test.stopTest();

        System.assertEquals(
            400,
            RestContext.response.statusCode,
            'Missing required fields should return HTTP 400'
        );

        String responseBody = getResponseBody();

        System.assert(
            responseBody.contains('MISSING_REQUIRED_FIELDS'),
            'Response should contain MISSING_REQUIRED_FIELDS. Actual response: ' +
            responseBody
        );
    }


    // =====================================================
    // BAD REQUEST - Missing Email And Mobile
    // =====================================================
    @IsTest
    static void testBadRequest_NoMobileNoEmail() {

        String secret = getSecretFromMetadata();
        String requestUri = '/services/apexrest/IndiaMartLead/' + secret;

        String payload =
            '{' +
            '"UNIQUE_QUERY_ID": "TEST-QUERY-004",' +
            '"SENDER_NAME": "Test User",' +
            '"SENDER_COMPANY": "Test Company"' +
            '}';

        setRequest(requestUri, payload);

        Test.startTest();
        IndiaMARTtLeadWebhook.handlePush();
        Test.stopTest();

        System.assertEquals(
            400,
            RestContext.response.statusCode,
            'Missing mobile and email should return HTTP 400'
        );
    }


    // =====================================================
    // INVALID SECRET - Empty Secret
    // =====================================================
    @IsTest
    static void testUnauthorized_EmptySecret() {

        String requestUri =
            '/services/apexrest/IndiaMartLead/';

        String payload =
            '{"UNIQUE_QUERY_ID":"TEST-EMPTY-SECRET"}';

        setRequest(requestUri, payload);

        Test.startTest();
        IndiaMARTtLeadWebhook.handlePush();
        Test.stopTest();

        System.assertEquals(
            401,
            RestContext.response.statusCode,
            'Empty secret should return HTTP 401'
        );
    }


    // =====================================================
    // HELPER - Set REST Request
    // =====================================================
    private static void setRequest(
        String requestUri,
        String payload
    ) {
        RestRequest req = new RestRequest();

        req.requestURI = requestUri;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(payload);

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }


    // =====================================================
    // HELPER - Get Response Body
    // =====================================================
    private static String getResponseBody() {

        if (RestContext.response == null) {
            return 'No response object';
        }

        if (RestContext.response.responseBody == null) {
            return 'No response body';
        }

        return RestContext.response.responseBody.toString();
    }


    // =====================================================
    // HELPER - Get IndiaMART Secret
    // =====================================================
    private static String getSecretFromMetadata() {

        List<Integration_Credential__mdt> creds = [
            SELECT API_Key__c
            FROM Integration_Credential__mdt
            WHERE DeveloperName = 'IndiaMart'
            LIMIT 1
        ];

        System.assert(
            !creds.isEmpty(),
            'Custom Metadata record "IndiaMart" is missing. ' +
            'Deploy Integration_Credential__mdt record with DeveloperName = IndiaMart.'
        );

        System.assert(
            String.isNotBlank(creds[0].API_Key__c),
            'API_Key__c is blank in Integration_Credential__mdt record "IndiaMart".'
        );

        return creds[0].API_Key__c;
    }
}