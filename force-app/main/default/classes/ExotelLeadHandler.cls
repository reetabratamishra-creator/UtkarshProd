@RestResource(urlMapping='/ExotelLeadHandler/*')
global class ExotelLeadHandler {
    
    @HttpGet
    global static void handleCall() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        System.debug('===== EXOTEL WEBHOOK HIT =====');
        System.debug('Time: ' + System.now());
        System.debug('All Params: ' + req.params);
        
        String callFrom       = req.params.get('From');        
        String callTo         = req.params.get('To');          
        String callSid        = req.params.get('CallSid');
        String status         = req.params.get('CallType');
        String dialCallStatus = req.params.get('DialCallStatus'); 
        
        System.debug('dialCallStatus value: ' + dialCallStatus);
        System.debug('All Params: ' + req.params);
         
        String normPhone = callFrom != null ? callFrom.replaceAll('[^0-9+]', '') : null;
        
        try {
            List<Lead> existing = new List<Lead>();
            if (normPhone != null && normPhone != '') {
                existing = [SELECT Id, CreatedDate FROM Lead WHERE Phone = :normPhone AND IsConverted = false 
            AND Status != 'Lost' ORDER BY CreatedDate DESC LIMIT 1];
            }
            
            Id leadId;
            Boolean reuseExisting = false;
            
            if (!existing.isEmpty() && existing[0].CreatedDate.addHours(24) > System.now()) {
                reuseExisting = true;
            }
            
            if (reuseExisting) {
                leadId = existing[0].Id;
            } else {
                Lead newLead = new Lead(
                    LastName    = 'Enquiry',
                    Company     = '(Exotel Inbound)',
                    Phone       = normPhone,
                    LeadSource  = 'INBOUND PHONE CALL',
                    Status      = 'Prospect',
                    Department_Name__c = 'Enquiry',
                    Description = 'Auto-created from inbound call. CallSid: ' + callSid + ', Status: ' + status
                );
                insert newLead;
                leadId = newLead.Id;
            }
            
            // ── Build Task Description ────────────────────────────────
            String taskDesc =
                'Exotel Call Summary\n' +
                '─────────────────────────\n' +
                'CallSid        : ' + (String.isBlank(callSid)        ? 'N/A' : callSid)        + '\n' +
                'From           : ' + (String.isBlank(callFrom)       ? 'N/A' : callFrom)       + '\n' +
                'To             : ' + (String.isBlank(callTo)         ? 'N/A' : callTo)         + '\n' +
                'Status         : ' + (String.isBlank(status)         ? 'N/A' : status)         + '\n' +
                'DialCallStatus : ' + (String.isBlank(dialCallStatus) ? 'N/A' : dialCallStatus);
            
            // ── Build Task ────────────────────────────────────────────
            Task callTask = new Task(
                WhoId           = leadId,
                Subject         = (dialCallStatus == 'completed' ? 'Inbound Call from ' : 'Missed Call from ') + callFrom,
                Status = (dialCallStatus == 'completed' ? 'Completed' : 
                dialCallStatus == 'no-answer' ? 'Completed' :
                dialCallStatus == 'busy'      ? 'Completed' :
                dialCallStatus == 'canceled'  ? 'Completed' : 'Completed'),                
                Priority        = 'Normal',
                Type            = 'Call',
                CallType        = 'Inbound',
                CallDisposition = dialCallStatus,
                ActivityDate    = Date.today(),
                Description     = taskDesc
            );
            
            // ── Set native Exotel CTI fields ──────────────────────────
            callTask.Exotel_CTI__Call_Sid__c       = callSid;
            callTask.Exotel_CTI__Call_Status__c    = status;
            callTask.Exotel_CTI__Call_Direction__c = 'Inbound';
            
            // ── Always insert new Task — every call = new Task ────────
            insert callTask;
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"ok"}');
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"status":"error","message":"' + e.getMessage() + '"}');
        }
    }
}