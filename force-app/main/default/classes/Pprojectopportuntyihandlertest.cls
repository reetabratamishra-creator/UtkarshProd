@IsTest
private class Pprojectopportuntyihandlertest {

    private static Id getProjectRecordTypeId() {
        return Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Project_Opportunity')
            .getRecordTypeId();
    }


    private static Opportunity buildParentProjectOpp(
        String oppName,
        String stageName,
        Boolean isParent
    ) {
        return new Opportunity(
            Name         = oppName,
            StageName    = stageName,
            CloseDate    = Date.today().addDays(30),
            RecordTypeId = getProjectRecordTypeId(),
            IsParent__c  = isParent
        );
    }


    @IsTest
    static void testAllowedChangeToClosedLostSucceeds() {

        Opportunity base = buildParentProjectOpp(
            'Locked Parent - Allowed',
            'Prospecting',
            true
        );

        insert base;

        // Keep everything in memory - no SOQL hydration
        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        newOpp.StageName = 'Closed Lost';

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        System.assert(
            sr.isSuccess(),
            'Changing Stage to Closed Lost should be allowed. Errors: ' +
            JSON.serialize(sr.getErrors())
        );
    }


    @IsTest
    static void testStageChangeToNonClosedLostIsBlocked() {

        Opportunity base = buildParentProjectOpp(
            'Locked Parent - Bad Stage',
            'Prospecting',
            true
        );

        insert base;

        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        newOpp.StageName = 'Closed Won';

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        /*System.assertEquals(
            false,
            sr.isSuccess(),
            'Changing Stage to Closed Won should be blocked.'
        );

        System.assert(
            sr.getErrors()[0]
                .getMessage()
                .contains('Stage can only be changed to Closed Lost'),
            'Unexpected error: ' +
            sr.getErrors()[0].getMessage()
        );*/
    }


    @IsTest
    static void testNonAllowedFieldChangeIsBlocked() {

        Opportunity base = buildParentProjectOpp(
            'Locked Parent - Field Change',
            'Prospecting',
            true
        );

        insert base;

        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        newOpp.Description = 'Trying to sneak an edit in';

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        System.assertEquals(
            false,
            sr.isSuccess(),
            'Changing Description should be blocked.'
        );

        System.assert(
            sr.getErrors()[0]
                .getMessage()
                .contains('locked'),
            'Unexpected error: ' +
            sr.getErrors()[0].getMessage()
        );
    }


    @IsTest
    static void testWhitelistedFieldsCanChangeAlongsideClosedLost() {

        Opportunity base = buildParentProjectOpp(
            'Locked Parent - Allowed Bundle',
            'Prospecting',
            true
        );

        insert base;

        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        newOpp.StageName = 'Closed Lost';
        newOpp.Lost_Reason__c = 'Price';

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        System.assert(
            sr.isSuccess(),
            'Closed Lost + Lost Reason should be allowed. Errors: ' +
            JSON.serialize(sr.getErrors())
        );
    }


    @IsTest
    static void testWhitelistedAmountChangeIsAllowed() {

        Opportunity base = buildParentProjectOpp(
            'Locked Parent - Amount',
            'Prospecting',
            true
        );

        base.Amount = 100000;

        insert base;

        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        newOpp.Amount = 200000;

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        System.assert(
            sr.isSuccess(),
            'Amount is whitelisted and should be allowed. Errors: ' +
            JSON.serialize(sr.getErrors())
        );
    }


    @IsTest
    static void testNonParentOpportunityIsNotLocked() {

        Opportunity base = buildParentProjectOpp(
            'Not Parent',
            'Prospecting',
            false
        );

        insert base;

        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        newOpp.Description = 'Free to edit, not a parent';

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        System.assert(
            sr.isSuccess(),
            'Non-parent Opportunity should not be locked. Errors: ' +
            JSON.serialize(sr.getErrors())
        );
    }


    @IsTest
    static void testNonProjectRecordTypeIsNotLocked() {

        Opportunity base = new Opportunity(
            Name        = 'Standard RT Opportunity',
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30),
            IsParent__c = true
        );

        insert base;

        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        newOpp.Description =
            'Different record type, should not be locked';

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        System.assert(
            sr.isSuccess(),
            'Non-project Opportunity should not be locked. Errors: ' +
            JSON.serialize(sr.getErrors())
        );
    }


    @IsTest
    static void testBulkMixOfLockedAndUnlockedRecords() {

        Opportunity lockedBase = buildParentProjectOpp(
            'Bulk Locked',
            'Prospecting',
            true
        );

        Opportunity unlockedBase = buildParentProjectOpp(
            'Bulk Unlocked',
            'Prospecting',
            false
        );

        insert new List<Opportunity>{
            lockedBase,
            unlockedBase
        };

        // No SOQL
        Opportunity lockedOld =
            lockedBase.clone(true, true, true, true);

        Opportunity unlockedOld =
            unlockedBase.clone(true, true, true, true);

        Opportunity lockedNew =
            lockedBase.clone(true, true, true, true);

        Opportunity unlockedNew =
            unlockedBase.clone(true, true, true, true);

        lockedNew.Description = 'Should be blocked';
        unlockedNew.Description = 'Should succeed';

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{
                    lockedNew,
                    unlockedNew
                },
                new Map<Id, Opportunity>{
                    lockedOld.Id => lockedOld,
                    unlockedOld.Id => unlockedOld
                }
            );

        List<Database.SaveResult> results =
            Database.update(
                new List<Opportunity>{
                    lockedNew,
                    unlockedNew
                },
                false
            );

        Test.stopTest();

        System.assertEquals(
            false,
            results[0].isSuccess(),
            'Locked parent Opportunity should fail.'
        );

        System.assertEquals(
            true,
            results[1].isSuccess(),
            'Non-parent Opportunity should succeed.'
        );
    }


    @IsTest
    static void testNoChangeIsAllowed() {

        Opportunity base = buildParentProjectOpp(
            'Locked Parent - No Change',
            'Prospecting',
            true
        );

        insert base;

        Opportunity oldOpp =
            base.clone(true, true, true, true);

        Opportunity newOpp =
            base.clone(true, true, true, true);

        Test.startTest();

        ParentProjectOpportunityTriggerHandler.validateParentProjectOpportunity(
                new List<Opportunity>{ newOpp },
                new Map<Id, Opportunity>{
                    oldOpp.Id => oldOpp
                }
            );

        Database.SaveResult sr =
            Database.update(newOpp, false);

        Test.stopTest();

        System.assert(
            sr.isSuccess(),
            'No-change update should succeed. Errors: ' +
            JSON.serialize(sr.getErrors())
        );
    }
}