public without sharing class UserDeptChangeTenderShareBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private Set<String> userDepartments;
    private List<String> tenderDepartmentNames;

    private Integer totalTenders = 0;
    private Integer failedScopes = 0;

    public UserDeptChangeTenderShareBatch(Set<String> userDepartments) {
        this.userDepartments = (userDepartments == null) ? new Set<String>() : userDepartments;

        // Convert user (normalized) departments -> Tender department values
        this.tenderDepartmentNames =
            new List<String>(TenderSharingHandler.getTenderDeptNames(this.userDepartments));
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> deptNames = this.tenderDepartmentNames;

        return Database.getQueryLocator([
            SELECT Id, Department_Name__c, OwnerId
            FROM Tender__c
            WHERE Department_Name__c IN :deptNames
            WITH SYSTEM_MODE
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Tender__c> scope) {
        if (scope == null || scope.isEmpty()) return;

        // If anything fails, undo partial work (e.g. old shares deleted but new ones not inserted)
        Savepoint sp = Database.setSavepoint();

        try {
            TenderSharingHandler.shareTenders(scope);
            totalTenders += scope.size();
        } catch (Exception ex) {
            Database.rollback(sp);
            failedScopes++;

            System.debug(LoggingLevel.ERROR,
                'UserDeptChangeTenderShareBatch execute failed: ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('UserDeptChangeTenderShareBatch finished. Departments: ' + userDepartments
            + ' | Tenders processed: ' + totalTenders
            + ' | Failed batches: ' + failedScopes);
    }
}