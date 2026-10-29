public with sharing class POManualReviewController {

    /*
    ===============================================================
    Wrapper returned to LWC
    ===============================================================
    */
    public class ManualReviewWrapper {

        @AuraEnabled public Id recordId;

        @AuraEnabled public String poNumber;
        @AuraEnabled public String poDate;
        @AuraEnabled public Decimal amount;

        @AuraEnabled public Boolean canEditPoNumber;
        @AuraEnabled public Boolean canEditPoDate;
        @AuraEnabled public Boolean canEditAmount;

        @AuraEnabled public Boolean reviewCompleted;
    }

    /*
    ===============================================================
    Get Record Details
    ===============================================================
    */
    @AuraEnabled(cacheable=true)
    public static ManualReviewWrapper getReviewDetails(Id recordId) {

        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        if (!Schema.sObjectType.PO_Line_Items__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to this record.');
        }

        PO_Line_Items__c record = [
            SELECT
                Id,
                PO_Number__c,
                PO_Date__c,
                Amount__c,
                Manual_Review_Completed__c
            FROM PO_Line_Items__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        ManualReviewWrapper response = new ManualReviewWrapper();

        response.recordId = record.Id;
        response.poNumber = record.PO_Number__c;
        response.poDate = record.PO_Date__c;
        response.amount = record.Amount__c;
        response.reviewCompleted = record.Manual_Review_Completed__c;

        if (record.Manual_Review_Completed__c) {

            response.canEditPoNumber = false;
            response.canEditPoDate = false;
            response.canEditAmount = false;

        } else {

            response.canEditPoNumber = isMissing(record.PO_Number__c);
            response.canEditPoDate = isMissing(record.PO_Date__c);
            response.canEditAmount = (record.Amount__c == null);

        }

        return response;
    }

    /*
    ===============================================================
    Save Manual Review
    ===============================================================
    */
    @AuraEnabled
    public static void saveReview(
        Id recordId,
        String poNumber,
        String poDate,
        Decimal amount
    ) {

        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        if (!Schema.sObjectType.PO_Line_Items__c.isUpdateable()) {
            throw new AuraHandledException('You do not have permission to update this record.');
        }

        PO_Line_Items__c existingRecord = [
            SELECT
                Id,
                PO_Number__c,
                PO_Date__c,
                Amount__c,
                Manual_Review_Completed__c
            FROM PO_Line_Items__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (existingRecord.Manual_Review_Completed__c) {
            throw new AuraHandledException(
                'Manual review has already been completed for this record.'
            );
        }

        PO_Line_Items__c updateRecord = new PO_Line_Items__c(
            Id = recordId
        );

        /*
        Update only fields that were editable.
        Existing values are never overwritten.
        */

        if (isMissing(existingRecord.PO_Number__c)) {
            updateRecord.PO_Number__c = poNumber;
        }

        if (isMissing(existingRecord.PO_Date__c)) {
            updateRecord.PO_Date__c = poDate;
        }

        if (existingRecord.Amount__c == null) {
            updateRecord.Amount__c = amount;
        }

        updateRecord.Manual_Review_Completed__c = true;
        updateRecord.Approval_Status__c = 'Submit for Approval';
        updateRecord.Sent_For_Approval__c = true;

        Savepoint sp = Database.setSavepoint();

        try {

            update updateRecord;

            Approval.ProcessSubmitRequest approvalRequest =
                new Approval.ProcessSubmitRequest();

            approvalRequest.setObjectId(updateRecord.Id);
            approvalRequest.setProcessDefinitionNameOrId('PO_Approval_Process');
            approvalRequest.setSkipEntryCriteria(false);

            Approval.ProcessResult result =
                Approval.process(approvalRequest);

            if (!result.isSuccess()) {

                Database.rollback(sp);

                throw new AuraHandledException(
                    'Unable to submit record for approval.'
                );
            }

        } catch (Exception e) {

            Database.rollback(sp);

            throw new AuraHandledException(
                'Error while submitting for approval: ' + e.getMessage()
            );
        }
    }

    /*
    ===============================================================
    Helper Method
    ===============================================================
    */

    private static Boolean isMissing(String value) {

        if (String.isBlank(value)) {
            return true;
        }

        String normalized = value.trim().toLowerCase();

        return normalized.contains('not found')
            || normalized.contains('not mentioned')
            || normalized.contains('not available');
    }
}