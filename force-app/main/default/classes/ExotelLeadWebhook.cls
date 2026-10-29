@RestResource(urlMapping='/exotelLead/*')
global with sharing class ExotelLeadWebhook {
    @HttpGet
    global static void handleCall() {
        RestRequest req = RestContext.request;
        String callFrom = req.params.get('CallFrom');
        String callTo   = req.params.get('CallTo');
        String callSid  = req.params.get('CallSid');
        String status   = req.params.get('CallStatus');

        String normPhone = callFrom?.replaceAll('[^0-9+]', '');
        List<Lead> existing = [SELECT Id FROM Lead WHERE Phone = :normPhone LIMIT 1];

        if (existing.isEmpty()) {
            insert new Lead(
                LastName   = 'Unknown Caller',
                Company    = 'Unknown (Exotel Inbound)',
                Phone      = normPhone,
                LeadSource = 'Exotel - ' + callTo,
                Status     = 'Open - Not Contacted',
                Description = 'Auto-created from inbound call. CallSid: ' + callSid + ', Status: ' + status
            );
        }
        RestContext.response.statusCode = 200;
    }
}