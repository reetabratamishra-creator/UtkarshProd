@RestResource(urlMapping='/IndiaMartLead/*')
global without sharing class IndiaMARTtLeadWebhook {

    @HttpPost
    global static void handlePush() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            // 1. Secret is the last URL segment: /IndiaMartLead/<SECRET>
            List<String> segments = req.requestURI.split('/');
            String suppliedSecret = segments.isEmpty() ? '' : segments[segments.size() - 1];

            if (!isValidSecret(suppliedSecret)) {
                res.statusCode = 401;
                res.responseBody = Blob.valueOf('{"CODE":401,"STATUS":"UNAUTHORIZED"}');
                return;
            }

            // 2. IndiaMart's sample shows the lead data nested under body.RESPONSE.
            //    Handle both that shape and a flat payload defensively.
            Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            Map<String, Object> bodyMap = raw.containsKey('body') ? (Map<String, Object>) raw.get('body') : raw;
            Map<String, Object> data = bodyMap.containsKey('RESPONSE') ? (Map<String, Object>) bodyMap.get('RESPONSE') : bodyMap;

            String uniqueQueryId = (String) data.get('UNIQUE_QUERY_ID');
            String senderName    = String.isNotBlank((String) data.get('SENDER_NAME')) ? (String) data.get('SENDER_NAME') : 'IndiaMART Buyer';
            String mobile        = (String) data.get('SENDER_MOBILE');
            String email         = (String) data.get('SENDER_EMAIL');
            String company       = (String) data.get('SENDER_COMPANY');
            String subject       = (String) data.get('SUBJECT');
            String city          = (String) data.get('SENDER_CITY');
            String state         = (String) data.get('SENDER_STATE');
            String Country       = (string) data.get('SENDER_COUNTRY');
            String countryIso    = (String) data.get('SENDER_COUNTRY_ISO');
            String message       = (String) data.get('QUERY_MESSAGE');

            if (String.isBlank(uniqueQueryId) || (String.isBlank(mobile) && String.isBlank(email))) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"CODE":400,"STATUS":"MISSING_REQUIRED_FIELDS"}');
                return;
            }

            List<String> nameParts = senderName.trim().split(' ', 2);
            String firstName = nameParts.size() > 1 ? nameParts[0] : null;
            String lastName  = nameParts.size() > 1 ? nameParts[1] : nameParts[0];

            Lead ld = new Lead(
                IndiaMART_Query_Id__c = uniqueQueryId,
                FirstName   = firstName,
                LastName    = lastName,
                Company     = String.isNotBlank(company) ? company : senderName,
                Phone       = mobile,
                Email       = email,
                City__c     = city,
                State__c    = state,
                Country__c  = Country,
                //countrycode__c  = countryIso,
                //Description = subject + (String.isNotBlank(message) ? '\n' + message : ''),
                LeadSource  = 'INDIAMART',
                Status      = 'Prospect'
            );

            // upsert on the External ID prevents duplicate leads on retries
            upsert ld IndiaMART_Query_Id__c;

            res.statusCode = 200; // IndiaMart treats HTTP 200 as delivery confirmation
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'CODE' => 200, 'STATUS' => 'SUCCESS', 'leadId' => ld.Id
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'CODE' => 500, 'STATUS' => 'ERROR', 'error' => e.getMessage()
            }));
        }
    }

    private static Boolean isValidSecret(String supplied) {
        Integration_Credential__mdt cred = [
            SELECT API_Key__c FROM Integration_Credential__mdt
            WHERE DeveloperName = 'IndiaMart' WITH SYSTEM_MODE LIMIT 1
        ];
        return cred != null && String.isNotBlank(supplied) && cred.API_Key__c == supplied;
    }
}