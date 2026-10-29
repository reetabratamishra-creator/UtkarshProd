@isTest
private class TestCaseReopenController {

    private static String nonOpenStatus() {
        for (Schema.PicklistEntry pe : Case.Status.getDescribe().getPicklistValues()) {
            if (pe.isActive() && !'Open'.equalsIgnoreCase(pe.getValue())) {
                return pe.getValue();
            }
        }
        return 'Open';
    }

    private static Case buildCase() {
        Case cs = new Case(
            Subject                = 'Reopen Test Case',
            Status                 = nonOpenStatus(),
            Origin                 = 'Web',
            RCA__c                 = 'Root cause captured earlier',
            Preventive_Action__c   = 'Preventive action captured earlier'
        );
        insert cs;
        return cs;
    }

    @isTest
    static void testGetCaseInfo() {
        Case cs = buildCase();

        Test.startTest();
        CaseReopenController.CaseInfo info = CaseReopenController.getCaseInfo(cs.Id);
        Test.stopTest();

        System.assertEquals(cs.Id, info.caseId, 'Case Id should match');
        System.assertNotEquals(null, info.caseNumber, 'Case Number should be returned');
        System.assertEquals(false, info.alreadyOpen, 'Case should not start as Open');
    }

    @isTest
    static void testReopenCase() {
        Case cs = buildCase();

        Test.startTest();
        String caseNumber = CaseReopenController.reopenCase(cs.Id);
        Test.stopTest();

        Case updated = [
            SELECT Id, CaseNumber, Status, RCA__c, Preventive_Action__c
            FROM Case
            WHERE Id = :cs.Id
            LIMIT 1
        ];

        System.assertEquals('Open', updated.Status, 'Status should be Open');
        System.assertEquals(null, updated.RCA__c, 'RCA should be blank');
        System.assertEquals(null, updated.Preventive_Action__c, 'Preventive Action should be blank');
        System.assertEquals(updated.CaseNumber, caseNumber, 'Returned Case Number should match');
    }

    @isTest
    static void testReopenAlreadyOpenCase() {
        Case cs = buildCase();
        cs.Status = 'Open';
        update cs;

        Test.startTest();
        CaseReopenController.CaseInfo info = CaseReopenController.getCaseInfo(cs.Id);
        CaseReopenController.reopenCase(cs.Id);
        Test.stopTest();

        Case updated = [SELECT Status, RCA__c FROM Case WHERE Id = :cs.Id LIMIT 1];
        System.assertEquals(true, info.alreadyOpen, 'alreadyOpen flag should be true');
        System.assertEquals('Open', updated.Status, 'Status should stay Open');
        System.assertEquals(null, updated.RCA__c, 'RCA should be blank');
    }

    @isTest
    static void testNullAndDeletedCase() {
        Case cs = buildCase();
        delete cs;

        Boolean nullIdError = false;
        Boolean deletedIdError = false;

        Test.startTest();
        try {
            CaseReopenController.getCaseInfo(null);
        } catch (Exception e) {
            nullIdError = true;
        }
        try {
            CaseReopenController.reopenCase(cs.Id);
        } catch (Exception e) {
            deletedIdError = true;
        }
        Test.stopTest();

        System.assertEquals(true, nullIdError, 'Null Id should throw');
        System.assertEquals(true, deletedIdError, 'Deleted Case should throw');
    }
}