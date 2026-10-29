public with sharing class PODashboardController {

    /*
    ==========================================================
    Wrapper
    ==========================================================
    */
    public class DashboardWrapper {

        @AuraEnabled
        public Integer totalFiles;

        @AuraEnabled
        public Integer missingFields;

        @AuraEnabled
        public Integer submitForApproval;

        @AuraEnabled
        public Integer failed;

        @AuraEnabled
        public List<PO_Line_Items__c> records;
    }

    /*
    ==========================================================
    Dashboard Data
    ==========================================================
    */
    @AuraEnabled(cacheable=true)
    public static DashboardWrapper getDashboard(Id opportunityId) {

        if(opportunityId == null){
            throw new AuraHandledException('Opportunity Id is required.');
        }

        if(!Schema.sObjectType.PO_Line_Items__c.isAccessible()){
            throw new AuraHandledException(
                'You do not have permission to access PO records.'
            );
        }

        List<PO_Line_Items__c> poRecords = [

            SELECT
                Id,
                Name,
                Status__c,
                Approval_Status__c,
                Manual_Review_Completed__c,

                PO_Number__c,
                PO_Date__c,
                Amount__c,

                CreatedDate

            FROM PO_Line_Items__c

            WHERE Opportunity__c = :opportunityId

            ORDER BY CreatedDate DESC
        ];

        DashboardWrapper wrapper = new DashboardWrapper();

        wrapper.records = poRecords;

        wrapper.totalFiles = poRecords.size();

        wrapper.missingFields = 0;
        wrapper.submitForApproval = 0;
        wrapper.failed = 0;

        /*
        ==========================================================
        Calculate Counts
        ==========================================================
        */

        for(PO_Line_Items__c rec : poRecords){

            /*
            Missing Fields
            */
            if(rec.Status__c == 'Manual Review Required'){
                wrapper.missingFields++;
            }

            /*
            Pending Approval
            */
            if(rec.Approval_Status__c == 'Submit for Approval'){
                wrapper.submitForApproval++;
            }

            /*
            Failed Extraction
            */
            if(rec.Status__c == 'Failed'){
                wrapper.failed++;
            }

        }

        return wrapper;
    }

}