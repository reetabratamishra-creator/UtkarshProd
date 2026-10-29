public without sharing class CaseReopenController {

    public class CaseInfo {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean alreadyOpen;
    }

    @AuraEnabled(cacheable=true)
    public static CaseInfo getCaseInfo(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('No Case record found.');
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Status
            FROM Case
            WHERE Id = :caseId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('No Case record found.');
        }

        CaseInfo info      = new CaseInfo();
        info.caseId        = cases[0].Id;
        info.caseNumber    = cases[0].CaseNumber;
        info.subject       = cases[0].Subject;
        info.status        = cases[0].Status;
        info.alreadyOpen   = 'Open'.equalsIgnoreCase(cases[0].Status);
        return info;
    }

    @AuraEnabled
    public static String reopenCase(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('No Case record found.');
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, Status, RCA__c, Preventive_Action__c
            FROM Case
            WHERE Id = :caseId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (cases.isEmpty()) {
            throw new AuraHandledException('No Case record found.');
        }

        Case cs                  = cases[0];
        cs.Status                = 'Open';
        cs.RCA__c                = null;
        cs.Preventive_Action__c  = null;

        try {
            Database.update(cs, true, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            throw new AuraHandledException('Could not reopen the Case: ' + e.getMessage());
        }

        return cs.CaseNumber;
    }
}