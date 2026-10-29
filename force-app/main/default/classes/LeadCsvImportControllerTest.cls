@IsTest
public class LeadCsvImportControllerTest {

    @IsTest
    static void testGetLeadSourceOptions() {
        Test.startTest();
        List<String> options = LeadCsvImportController.getLeadSourceOptions();
        Test.stopTest();

        System.assert(options.size() > 0);
    }

    @IsTest
    static void testSuccessfulImport() {

        List<LeadCsvImportController.LeadRowWrapper> rows = new List<LeadCsvImportController.LeadRowWrapper>();

        LeadCsvImportController.LeadRowWrapper row = new LeadCsvImportController.LeadRowWrapper();
        row.rowKey = 'row-0';
        row.firstName = 'John';
        row.lastName = 'Doe';
        row.phone = '9876543210';
        row.departmentName = 'High Mast & Polygonal';
        row.email = 'john@test.com';

        rows.add(row);

        String jsonData = JSON.serialize(rows);

        Test.startTest();
        LeadCsvImportController.ImportResult result = LeadCsvImportController.processLeadImport(jsonData,'Web',null,null);
        Test.stopTest();

        System.assertEquals(1, result.totalProcessed);
        System.assertEquals(1, result.successCount);
        System.assertEquals(0, result.failCount);

        Lead l = [SELECT Id, FirstName, LastName, Phone, Company FROM Lead WHERE Phone = '9876543210' LIMIT 1];

        System.assertEquals('John', l.FirstName);
        System.assertEquals('Doe', l.LastName);
    }

    @IsTest
    static void testInvalidPhone() {

        List<LeadCsvImportController.LeadRowWrapper> rows = new List<LeadCsvImportController.LeadRowWrapper>();

        LeadCsvImportController.LeadRowWrapper row = new LeadCsvImportController.LeadRowWrapper();
        row.rowKey = 'row-0';
        row.firstName = 'John';
        row.lastName = 'Doe';
        row.phone = '12345'; 
        row.departmentName = 'High Mast & Polygonal';
        row.email = 'john@test.com';

        rows.add(row);

        Test.startTest();
        LeadCsvImportController.ImportResult result = LeadCsvImportController.processLeadImport(JSON.serialize(rows), 'Web', null, null);
        Test.stopTest();

        System.assertEquals(0, result.successCount);
        System.assertEquals(1, result.failCount);
        System.assert(result.errors[0].message.contains('Phone number must contain exactly 10 digits'));
    }

    @IsTest
    static void testRowLimitExceeded() {

        List<LeadCsvImportController.LeadRowWrapper> rows = new List<LeadCsvImportController.LeadRowWrapper>();

        for (Integer i = 0; i < 51; i++) {
            LeadCsvImportController.LeadRowWrapper row = new LeadCsvImportController.LeadRowWrapper();
            row.rowKey = 'row-' + i;
            row.firstName = 'Test';
            row.lastName = 'User';
            row.phone = '9876543210';
            row.departmentName = 'High Mast & Polygonal';
            rows.add(row);
        }

        Test.startTest();
        try {
            LeadCsvImportController.processLeadImport(JSON.serialize(rows), 'Web', null, null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testImportWithAttachment() {
    
        List<LeadCsvImportController.LeadRowWrapper> rows = new List<LeadCsvImportController.LeadRowWrapper>();
    
        LeadCsvImportController.LeadRowWrapper row = new LeadCsvImportController.LeadRowWrapper();
        row.rowKey = 'row-0';
        row.firstName = 'John';
        row.lastName = 'Doe';
        row.phone = '9876543210';
        row.departmentName = 'High Mast & Polygonal';
        row.email = 'john@test.com';
        rows.add(row);
    
        String jsonData = JSON.serialize(rows);
    
        String fileName = 'TestFile.txt';
        String fileBase64 = EncodingUtil.base64Encode(Blob.valueOf('Hello World'));
    
        Test.startTest();
        LeadCsvImportController.ImportResult result = LeadCsvImportController.processLeadImport(jsonData, 'Web', fileName, fileBase64);
        Test.stopTest();
    
        System.assertEquals(1, result.successCount);
    
        Lead l = [
            SELECT Id
            FROM Lead
            WHERE Phone = '9876543210'
            LIMIT 1
        ];
    
        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :l.Id
        ];
    
        System.assertEquals(1, links.size());
    
        ContentVersion cv = [
            SELECT Id, Title
            FROM ContentVersion
            WHERE ContentDocumentId = :links[0].ContentDocumentId
            LIMIT 1
        ];
    
        System.assertEquals(fileName, cv.Title);
    }
    
    @IsTest
    static void testInvalidEmail() {
    
        List<LeadCsvImportController.LeadRowWrapper> rows =
            new List<LeadCsvImportController.LeadRowWrapper>();
    
        LeadCsvImportController.LeadRowWrapper row =
            new LeadCsvImportController.LeadRowWrapper();
        row.rowKey = 'row-0';
        row.firstName = 'John';
        row.lastName = 'Doe';
        row.phone = '9876543210';
        row.departmentName = 'High Mast & Polygonal';
        row.email = 'invalid-email';
    
        rows.add(row);
    
        Test.startTest();
        LeadCsvImportController.ImportResult result =
            LeadCsvImportController.processLeadImport(
                JSON.serialize(rows),
                'Web',
                null,
                null
            );
        Test.stopTest();
    
        System.assertEquals(0, result.successCount);
        System.assertEquals(1, result.failCount);
        System.assert(result.errors[0].message.contains('Email address is invalid'));
    }
}