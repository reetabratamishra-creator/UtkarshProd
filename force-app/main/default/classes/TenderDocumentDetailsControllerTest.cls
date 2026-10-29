@IsTest
private class TenderDocumentDetailsControllerTest {

    @TestSetup
    static void setupData() {

        // Create Tender
        Tender__c tender = new Tender__c(
            Department_Name__c = 'High Mast & Polygonal'
        );
        database.insert (tender, AccessLevel.SYSTEM_MODE);


        // Create Project linked to Tender
        Project__c project = new Project__c(
            Name = 'Test Project',
            Tender__c = tender.Id 
        );
        database.insert (project,AccessLevel.SYSTEM_MODE);


        // Create Tender Document
        Tender_Docoment_Details__c document = new Tender_Docoment_Details__c(
            Tender__c = tender.Id,
            Name__c = 'Test Document',
            Type__c = 'PDF',
            Download_URL__c = 'https://example.com/test.pdf',
            Download_URL_Text__c = 'Download Test Document'
        );
        database.insert (document, AccessLevel.SYSTEM_MODE);
    }


    @IsTest
    static void testGetDocumentsUsingTenderId() {

        Tender__c tender = [
            SELECT Id
            FROM Tender__c
            WITH SYSTEM_MODE LIMIT 1 
        ];

        Test.startTest();

        List<Tender_Docoment_Details__c> result =
            TenderDocumentDetailsController.getDocuments(tender.Id);

        Test.stopTest();

        // Note: controller's SOQL does not select Tender__c, so we can only
        // assert on fields it actually queries (e.g. Name__c), not Tender__c.
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
        System.assertEquals('Test Document', result[0].Name__c);
    }


    @IsTest
    static void testGetDocumentsUsingProjectId() {

        Project__c project = [
            SELECT Id, Tender__c
            FROM Project__c
            WITH SYSTEM_MODE LIMIT 1 
        ];

        Test.startTest();

        List<Tender_Docoment_Details__c> result =
            TenderDocumentDetailsController.getDocuments(project.Id);

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
        System.assertEquals('Test Document', result[0].Name__c);
    }


    @IsTest
    static void testGetDocumentsUsingProjectOpportunity() {

        Tender__c tender = [
            SELECT Id
            FROM Tender__c
             WITH SYSTEM_MODE LIMIT 1
        ];

        RecordType projectOppRecordType = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Opportunity'
            AND DeveloperName = 'Project_Opportunity'
            WITH SYSTEM_MODE LIMIT 1
        ];

        Opportunity opp = new Opportunity(
            Name = 'Project Opportunity Test',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = projectOppRecordType.Id,
            Tender__c = tender.Id
        );

        database.insert (opp, AccessLevel.SYSTEM_MODE);

        Test.startTest();

        List<Tender_Docoment_Details__c> result =
            TenderDocumentDetailsController.getDocuments(opp.Id);

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
        System.assertEquals('Test Document', result[0].Name__c);
    }


    @IsTest
    static void testGetDocumentsUsingTenderOpportunity() {

        Tender__c tender = [
            SELECT Id
            FROM Tender__c
            WITH SYSTEM_MODE LIMIT 1 
        ];

        RecordType tenderOppRecordType = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Opportunity'
            AND DeveloperName = 'Tender_Opportunity'
            WITH SYSTEM_MODE LIMIT 1 
        ];

        Opportunity opp = new Opportunity(
            Name = 'Tender Opportunity Test',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = tenderOppRecordType.Id,
            Tender__c = tender.Id
        );

        database.insert (opp, AccessLevel.SYSTEM_MODE);

        Test.startTest();

        List<Tender_Docoment_Details__c> result =
            TenderDocumentDetailsController.getDocuments(opp.Id);

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
        System.assertEquals('Test Document', result[0].Name__c);
    }


    @IsTest
    static void testInvalidOpportunityRecordType() {

        // Create an Opportunity using the default/available record type
        RecordType defaultOppRecordType = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Opportunity'
            AND IsActive = true
            WITH SYSTEM_MODE LIMIT 1 
        ];

        Opportunity opp = new Opportunity(
            Name = 'Invalid Record Type Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            RecordTypeId = defaultOppRecordType.Id
        );

        database.insert (opp, AccessLevel.SYSTEM_MODE);

        Test.startTest();

        try {
            TenderDocumentDetailsController.getDocuments(opp.Id);
            System.assert(false, 'Expected AuraHandledException');
        }
        catch (AuraHandledException e) {
            // AuraHandledException.getMessage() returns the generic
            // "Script-thrown exception" unless the controller explicitly
            // calls setMessage(); the controller here does not.
            System.assertEquals(
                'Script-thrown exception',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testProjectWithoutTender() {

        Project__c project = new Project__c(
            Name = 'Project Without Tender'
        );
        database.insert (project, AccessLevel.SYSTEM_MODE);

        Test.startTest();

        try {
            TenderDocumentDetailsController.getDocuments(project.Id);
            System.assert(false, 'Expected AuraHandledException');
        }
        catch (AuraHandledException e) {
            System.assertEquals(
                'Script-thrown exception',
                e.getMessage()
            );
        }

        Test.stopTest();
    }


    @IsTest
    static void testNullRecordId() {

        Test.startTest();

        try {
            TenderDocumentDetailsController.getDocuments(null);
            System.assert(false, 'Expected AuraHandledException');
        }
        catch (AuraHandledException e) {
            System.assertEquals(
                'Script-thrown exception',
                e.getMessage()
            );
        }

        Test.stopTest();
    }
}