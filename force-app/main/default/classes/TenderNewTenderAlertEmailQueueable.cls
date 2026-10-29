/**
 * @description Sends New Tender Alert emails asynchronously so Tender insert
 *              sharing and other trigger work are not blocked by email SOQL.
 *              Reuses TenderStatusEmailHandler.handleAfterInsert unchanged.
 */
public without sharing class TenderNewTenderAlertEmailQueueable implements Queueable {
    @TestVisible
    private static final Integer CHUNK_SIZE = 40;

    private List<Id> remainingIds;

    public TenderNewTenderAlertEmailQueueable(Set<Id> tenderIds) {
        this.remainingIds = toIdList(tenderIds);
    }

    public TenderNewTenderAlertEmailQueueable(List<Id> tenderIds) {
        this.remainingIds = tenderIds == null ? new List<Id>() : new List<Id>(tenderIds);
    }

    /**
     * Enqueues this job for the given Tender Ids. Safe to call with null/empty.
     * Used from TenderShareTrigger (UI insert) and ProbableBidderBatch.finish()
     * (Tender247 insert).
     */
    public static void enqueue(Set<Id> tenderIds) {
        List<Id> ids = toIdList(tenderIds);
        if (ids.isEmpty()) {
            return;
        }
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            System.debug(
                LoggingLevel.ERROR,
                'TenderNewTenderAlertEmailQueueable skipped: queueable limit reached'
            );
            return;
        }
        System.enqueueJob(new TenderNewTenderAlertEmailQueueable(ids));
    }

    public void execute(QueueableContext context) {
        if (remainingIds == null || remainingIds.isEmpty()) {
            return;
        }

        Integer chunkSize = Test.isRunningTest() ? remainingIds.size() : CHUNK_SIZE;
        if (chunkSize < 1) {
            chunkSize = CHUNK_SIZE;
        }

        List<Id> currentChunk = new List<Id>();
        List<Id> nextIds = new List<Id>();
        Integer index = 0;
        for (Id tenderId : remainingIds) {
            if (tenderId == null) {
                continue;
            }
            if (index < chunkSize) {
                currentChunk.add(tenderId);
            } else {
                nextIds.add(tenderId);
            }
            index++;
        }

        if (!currentChunk.isEmpty()) {
            processChunk(currentChunk);
        }
        enqueueNext(nextIds);
    }

    private static void processChunk(List<Id> currentChunk) {
        List<Tender__c> tendersToEmail;
        try {
            tendersToEmail = [
                SELECT Id, Contact__c, Tender_User_Choice__c, HOD_Choice__c, Tender_Stage__c
                FROM Tender__c
                WHERE Id IN :currentChunk
                AND New_Tender_Alert_Email_Sent__c = FALSE
            ];
        } catch (Exception queryEx) {
            System.debug(
                LoggingLevel.ERROR,
                'TenderNewTenderAlertEmailQueueable query failed: ' +
                    queryEx.getMessage() +
                    '\n' +
                    queryEx.getStackTraceString()
            );
            return;
        }

        if (tendersToEmail.isEmpty()) {
            return;
        }

        try {
            TenderStatusEmailHandler.handleAfterInsert(tendersToEmail);
            markEmailsSent(tendersToEmail);
        } catch (Exception sendEx) {
            System.debug(
                LoggingLevel.ERROR,
                'TenderNewTenderAlertEmailQueueable send failed: ' +
                    sendEx.getMessage() +
                    '\n' +
                    sendEx.getStackTraceString()
            );
        }
    }

    private static void markEmailsSent(List<Tender__c> tendersToEmail) {
        List<Tender__c> sentUpdates = new List<Tender__c>();
        for (Tender__c tender : tendersToEmail) {
            sentUpdates.add(
                new Tender__c(
                    Id = tender.Id,
                    New_Tender_Alert_Email_Sent__c = true
                )
            );
        }

        List<Database.SaveResult> results = Database.update(sentUpdates, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                System.debug(
                    LoggingLevel.ERROR,
                    'TenderNewTenderAlertEmailQueueable failed to mark sent for ' +
                        sentUpdates[i].Id +
                        ': ' +
                        results[i].getErrors()[0].getMessage()
                );
            }
        }
    }

    private static void enqueueNext(List<Id> nextIds) {
        if (nextIds == null || nextIds.isEmpty() || Test.isRunningTest()) {
            return;
        }
        if (Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            System.debug(
                LoggingLevel.ERROR,
                'TenderNewTenderAlertEmailQueueable chain skipped: queueable limit reached'
            );
            return;
        }
        System.enqueueJob(new TenderNewTenderAlertEmailQueueable(nextIds));
    }

    private static List<Id> toIdList(Set<Id> tenderIds) {
        List<Id> ids = new List<Id>();
        if (tenderIds == null) {
            return ids;
        }
        for (Id tenderId : tenderIds) {
            if (tenderId != null) {
                ids.add(tenderId);
            }
        }
        return ids;
    }
}