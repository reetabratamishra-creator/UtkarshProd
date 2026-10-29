/*
@IsTest
private class PolymerHDPEBatchTest {

private class PolymerHDPEMock implements HttpCalloutMock {

    public HttpResponse respond(HttpRequest req) {

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        String endpoint = req.getEndpoint();

        if (endpoint != null &&
            endpoint.contains('generateContent')) {

            String body = req.getBody();

            if (body != null &&
                body.contains('HDPE_TENDER')) {

                res.setStatusCode(200);
                res.setBody(
                    '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"HDPE\\",\\"reasoning\\":\\"HDPE product keyword matched\\"}"}]}}]}'
                );
            }

            

            else if (body != null &&
                     body.contains('POLYMER_TENDER')) {

                res.setStatusCode(200);
                res.setBody(
                    '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"Polymer\\",\\"reasoning\\":\\"Polymer keyword matched\\"}"}]}}]}'
                );
            }

            else if (body != null &&
                     body.contains('NO_MATCH_TENDER')) {

                res.setStatusCode(200);
                res.setBody(
                    '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"None\\",\\"reasoning\\":\\"No keyword matched\\"}"}]}}]}'
                );
            }

            else if (body != null &&
                     body.contains('GEMINI_ERROR_TENDER')) {

                res.setStatusCode(400);
                res.setBody(
                    '{"error":{"message":"Gemini test error"}}'
                );
            }

            else {

                res.setStatusCode(200);
                res.setBody(
                    '{"candidates":[{"content":{"parts":[{"text":"{\\"matchedDepartment\\":\\"None\\",\\"reasoning\\":\\"Default test response\\"}"}]}}]}'
                );
            }

            return res;
        }

        

        

        if (endpoint != null &&
            endpoint.contains('download500')) {

            res.setStatusCode(500);
            res.setBody('Download failed');

            return res;
        }

        

        if (endpoint != null &&
            endpoint.contains('emptyfile')) {

            res.setStatusCode(200);
            res.setBody('');

            return res;
        }

        

        if (endpoint != null &&
            endpoint.contains('downloadException')) {

            throw new CalloutException(
                'Download exception for test'
            );
        }

        

        res.setStatusCode(200);
        res.setBody('Test tender document content');

        return res;
    }
}

private static Tender__c createTender() {

    Tender__c tender = new Tender__c();

    tender.MergeProduct__c = true;
    tender.Department_Name__c = null;
    tender.Polymer_HDPE_Stage_Check__c = null;

    insert tender;

    return tender;
}

private static Tender_Docoment_Details__c createDocument(
    Id tenderId,
    String fileName,
    String typeValue,
    String downloadUrl
) {

    Tender_Docoment_Details__c doc =
        new Tender_Docoment_Details__c();

    doc.Name__c = fileName;
    doc.Type__c = typeValue;

    

    doc.Download_URL_Text__c = downloadUrl;

    

    Map<String, Schema.SObjectField> documentFields =
        Tender_Docoment_Details__c.SObjectType
            .getDescribe()
            .fields
            .getMap();

    if (documentFields.containsKey('Download_URL__c')) {

        doc.put(
            'Download_URL__c',
            downloadUrl
        );
    }

    

    for (String fieldName : documentFields.keySet()) {

        Schema.DescribeFieldResult fieldDescribe =
            documentFields
                .get(fieldName)
                .getDescribe();

        if (fieldDescribe.getType() ==
            Schema.DisplayType.REFERENCE) {

            for (Schema.SObjectType referenceType :
                fieldDescribe.getReferenceTo()) {

                if (referenceType ==
                    Tender__c.SObjectType) {

                    doc.put(
                        fieldName,
                        tenderId
                    );

                    break;
                }
            }
        }
    }

    insert doc;

    return doc;
}

private static Tender__c getTenderWithDocuments(Id tenderId) {

    
    List<String> tenderFields = new List<String>();
    for (Schema.SObjectField f : Schema.SObjectType.Tender__c.fields.getMap().values()) {
        Schema.DescribeFieldResult d = f.getDescribe();
        if (d.isAccessible()
            && d.getType() != Schema.DisplayType.ADDRESS
            && d.getType() != Schema.DisplayType.LOCATION) {
            tenderFields.add(d.getName());
        }
    }

    
    List<String> docFields = new List<String>();
    for (Schema.SObjectField f : Schema.SObjectType.Tender_Docoment_Details__c.fields.getMap().values()) {
        Schema.DescribeFieldResult d = f.getDescribe();
        if (d.isAccessible()
            && d.getType() != Schema.DisplayType.ADDRESS
            && d.getType() != Schema.DisplayType.LOCATION) {
            docFields.add(d.getName());
        }
    }

    String soql = 'SELECT ' + String.join(tenderFields, ', ')
        + ', (SELECT ' + String.join(docFields, ', ')
        + ' FROM Tender_Docoment_Details__r ORDER BY CreatedDate DESC)'
        + ' FROM Tender__c WHERE Id = :tenderId LIMIT 1';

    return (Tender__c) Database.query(soql);
}

    private static PolymerHDPEBatch newBatch() {
    PolymerHDPEBatch b = new PolymerHDPEBatch();
    b.ownerMap.clear();   
    return b;
}
    
@IsTest
static void testStart() {

    createTender();

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    Database.QueryLocator locator =
        batch.start(null);

    Test.stopTest();

    System.assertNotEquals(
        null,
        locator,
        'QueryLocator should not be null.'
    );
}

@IsTest
static void testFinish() {

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.finish(null);

    Test.stopTest();

    System.assert(
        true,
        'Finish method executed successfully.'
    );
}

@IsTest
static void testNoDocuments() {

    Tender__c tender =
        createTender();

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        false,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Failed - No Documents',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testUnsupportedFile() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'Tender.zip',
        'ZIP',
        'https://unsupported.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        true,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'No Supported Files',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testBlankDownloadUrl() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'BlankUrl.pdf',
        'PDF',
        null
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        true,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Checked - No Match',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testDownloadHttpError() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'Download500.pdf',
        'PDF',
        'https://download500.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        false,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Failed - Will Retry',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testDownloadException() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'DownloadException.pdf',
        'PDF',
        'https://downloadException.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        false,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Failed - Will Retry',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testEmptyFile() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'EmptyFile.pdf',
        'PDF',
        'https://emptyfile.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        false,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Failed - Will Retry',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testGeminiError() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'GEMINI_ERROR_TENDER.pdf',
        'PDF',
        'https://geminierror.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        false,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Failed - Will Retry',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testHDPEMatch() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'HDPE_TENDER.pdf',
        'PDF',
        'https://hdpe.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        true,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Matched',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testPolymerMatch() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'POLYMER_TENDER.pdf',
        'PDF',
        'https://polymer.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'Polymer',
        result.Product_Name__c
    );

    System.assertEquals(
        'Polymer',
        result.Department_Name__c
    );

    System.assertEquals(
        true,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Matched',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testNoMatch() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'NO_MATCH_TENDER.pdf',
        'PDF',
        'https://nomatch.test/file'
    );

    Tender__c scopeTender =
        getTenderWithDocuments(tender.Id);

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    
    PolymerHDPEBatch batch = newBatch();

    Test.startTest();

    batch.execute(
        null,
        new List<Tender__c>{
            scopeTender
        }
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        true,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Checked - No Match',
        result.Polymer_HDPE_Stage_Check__c
    );
}

@IsTest
static void testFullBatchExecution() {

    Tender__c tender =
        createTender();

    createDocument(
        tender.Id,
        'HDPE_TENDER_BATCH.pdf',
        'PDF',
        'https://batch.test/file'
    );

    Test.setMock(
        HttpCalloutMock.class,
        new PolymerHDPEMock()
    );

    Test.startTest();

    Database.executeBatch(
        new PolymerHDPEBatch(),
        1
    );

    Test.stopTest();

    Tender__c result = [
        SELECT
            Product_Name__c,
            Department_Name__c,
            Is_checked_Polymer_HDPE__c,
            Polymer_HDPE_Stage_Check__c,
            Reading_Polymer_HDPE_summary__c
        FROM Tender__c
        WHERE Id = :tender.Id
    ];

    System.assertEquals(
        'HDPE',
        result.Product_Name__c
    );

    System.assertEquals(
        'HDPE',
        result.Department_Name__c
    );

    System.assertEquals(
        true,
        result.Is_checked_Polymer_HDPE__c
    );

    System.assertEquals(
        'Matched',
        result.Polymer_HDPE_Stage_Check__c
    );

    System.assertNotEquals(
        null,
        result.Reading_Polymer_HDPE_summary__c
    );
}

}
*/
@IsTest
private class PolymerHDPEBatchTest {

    private static final Integer SUMMARY_MAX_LEN = 131072;

    // =====================================================================
    // HTTP MOCK (document download + Gemini)
    // =====================================================================
    private class PolymerHDPEMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint() == null ? '' : req.getEndpoint();

            // ---------- Gemini ----------
            if (endpoint.contains('generateContent')) {
                String body = req.getBody() == null ? '' : req.getBody();

                if (body.contains('GEMINI_ERROR_TENDER')) {
                    res.setStatusCode(400);
                    res.setBody('{"error":{"message":"Gemini test error"}}');
                } else if (body.contains('HDPE_TENDER')) {
                    res.setStatusCode(200);
                    res.setBody(geminiBody('HDPE', 'HDPE product keyword matched'));
                } else if (body.contains('POLYMER_TENDER')) {
                    res.setStatusCode(200);
                    res.setBody(geminiBody('Polymer', 'Polymer keyword matched'));
                } else {
                    // NO_MATCH_TENDER and anything else
                    res.setStatusCode(200);
                    res.setBody(geminiBody('None', 'No keyword matched'));
                }
                return res;
            }

            // ---------- Document downloads ----------
            if (endpoint.contains('download500')) {
                res.setStatusCode(500);
                res.setBody('Download failed');
                return res;
            }
            if (endpoint.contains('emptyfile')) {
                res.setStatusCode(200);
                res.setBody('');
                return res;
            }
            if (endpoint.contains('downloadException')) {
                throw new CalloutException('Download exception for test');
            }
            if (endpoint.contains('largefile')) {
                // Just over the 2MB MAX_FILE_BYTES_FOR_GEMINI guard
                res.setStatusCode(200);
                res.setBody('a'.repeat(2 * 1024 * 1024 + 1024));
                return res;
            }

            res.setStatusCode(200);
            res.setBody('Test tender document content');
            return res;
        }

        private String geminiBody(String department, String reasoning) {
            return '{"candidates":[{"content":{"parts":[{"text":"'
                + '{\\"matchedDepartment\\":\\"' + department
                + '\\",\\"reasoning\\":\\"' + reasoning + '\\"}"}]}}]}';
        }
    }

    // =====================================================================
    // TEST DATA HELPERS
    // =====================================================================
    private static Tender__c createTender() {
        return createTender(null);
    }

    // description == null -> Step 1 has no input (fired = false), goes to Step 2
    private static Tender__c createTender(String description) {
        Tender__c t = new Tender__c(
            MergeProduct__c = true,
            Department_Name__c = null,
            Polymer_HDPE_Stage_Check__c = null
        );
        if (description != null) {
            t.Tender_Description__c = description;
        }
        insert t;
        return t;
    }

    // Builds (does not insert) a document linked to the tender
    private static Tender_Docoment_Details__c buildDocument(
        Id tenderId, String fileName, String typeValue, String downloadUrl
    ) {
        Tender_Docoment_Details__c doc = new Tender_Docoment_Details__c();
        doc.Name__c = fileName;
        doc.Type__c = typeValue;
        doc.Download_URL_Text__c = downloadUrl;

        Map<String, Schema.SObjectField> fields =
            Tender_Docoment_Details__c.SObjectType.getDescribe().fields.getMap();

        if (fields.containsKey('Download_URL__c')) {
            doc.put('Download_URL__c', downloadUrl);
        }

        // Find the lookup / master-detail field pointing to Tender__c
        for (String fieldName : fields.keySet()) {
            Schema.DescribeFieldResult d = fields.get(fieldName).getDescribe();
            if (d.getType() == Schema.DisplayType.REFERENCE) {
                for (Schema.SObjectType refType : d.getReferenceTo()) {
                    if (refType == Tender__c.SObjectType) {
                        doc.put(fieldName, tenderId);
                        break;
                    }
                }
            }
        }
        return doc;
    }

    private static Tender_Docoment_Details__c createDocument(
        Id tenderId, String fileName, String typeValue, String downloadUrl
    ) {
        Tender_Docoment_Details__c doc = buildDocument(tenderId, fileName, typeValue, downloadUrl);
        insert doc;
        return doc;
    }

    // Tender with every readable field + child documents (as the batch start() would)
    private static Tender__c getTenderWithDocuments(Id tenderId) {
        List<String> tenderFields = new List<String>();
        for (Schema.SObjectField f : Schema.SObjectType.Tender__c.fields.getMap().values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.isAccessible()
                && d.getType() != Schema.DisplayType.ADDRESS
                && d.getType() != Schema.DisplayType.LOCATION) {
                tenderFields.add(d.getName());
            }
        }
        List<String> docFields = new List<String>();
        for (Schema.SObjectField f : Schema.SObjectType.Tender_Docoment_Details__c.fields.getMap().values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (d.isAccessible()
                && d.getType() != Schema.DisplayType.ADDRESS
                && d.getType() != Schema.DisplayType.LOCATION) {
                docFields.add(d.getName());
            }
        }
        String soql = 'SELECT ' + String.join(tenderFields, ', ')
            + ', (SELECT ' + String.join(docFields, ', ')
            + ' FROM Tender_Docoment_Details__r ORDER BY CreatedDate DESC)'
            + ' FROM Tender__c WHERE Id = :tenderId LIMIT 1';
        return (Tender__c) Database.query(soql);
    }

    // Batch with no dependency on real owner users from custom metadata
    private static PolymerHDPEBatch newBatch() {
        PolymerHDPEBatch b = new PolymerHDPEBatch();
        b.ownerMap.clear();
        return b;
    }

    private static Tender__c reload(Id tenderId) {
        return [
            SELECT Product_Name__c, Department_Name__c, Is_checked_Polymer_HDPE__c,
                   Polymer_HDPE_Stage_Check__c, Reading_Polymer_HDPE_summary__c, OwnerId
            FROM Tender__c
            WHERE Id = :tenderId
        ];
    }

    // All DML must happen BEFORE Test.startTest() so the mocked callouts are allowed.
    private static Tender__c executeOne(Id tenderId, PolymerHDPEBatch b) {
        Tender__c scope = getTenderWithDocuments(tenderId);
        Test.setMock(HttpCalloutMock.class, new PolymerHDPEMock());

        Test.startTest();
        b.execute(null, new List<Tender__c>{ scope });
        Test.stopTest();

        return reload(tenderId);
    }

    /*private static void assertOutcome(Tender__c r, String dept, Boolean checked, String stage) {
        System.assertEquals(dept, r.Product_Name__c, 'Product_Name__c');
        System.assertEquals(dept, r.Department_Name__c, 'Department_Name__c');
        System.assertEquals(checked, r.Is_checked_Polymer_HDPE__c, 'Is_checked_Polymer_HDPE__c');
        System.assertEquals(stage, r.Polymer_HDPE_Stage_Check__c, 'Polymer_HDPE_Stage_Check__c');
        System.assertNotEquals(null, r.Reading_Polymer_HDPE_summary__c, 'Summary must be written');
    }*/

    private static void assertSummaryContains(Tender__c r, String expected) {
        System.assert(
            r.Reading_Polymer_HDPE_summary__c.contains(expected),
            'Summary should contain [' + expected + '] but was: ' + r.Reading_Polymer_HDPE_summary__c
        );
    }

    // =====================================================================
    // start() / finish()
    // =====================================================================
    @IsTest
    static void testStart_returnsOnlyEligibleTenders() {
        Tender__c eligible = createTender();

        Tender__c alreadyMatched = new Tender__c(
            MergeProduct__c = true, Polymer_HDPE_Stage_Check__c = 'Matched');
        Tender__c notMerged = new Tender__c(MergeProduct__c = false);
        Tender__c hasDepartment = new Tender__c(
            MergeProduct__c = true, Department_Name__c = 'HDPE');
        insert new List<Tender__c>{ alreadyMatched, notMerged, hasDepartment };

        PolymerHDPEBatch batch = newBatch();

        Test.startTest();
        Database.QueryLocator locator = batch.start(null);
        Test.stopTest();

        System.assertNotEquals(null, locator, 'QueryLocator should not be null');

        Set<Id> returned = new Set<Id>();
        Database.QueryLocatorIterator it = locator.iterator();
        while (it.hasNext()) {
            returned.add(((Tender__c) it.next()).Id);
        }

        System.assert(returned.contains(eligible.Id), 'Eligible tender must be returned');
        System.assert(!returned.contains(alreadyMatched.Id), 'Matched tender must be excluded');
        System.assert(!returned.contains(notMerged.Id), 'Non-merged tender must be excluded');
        System.assert(!returned.contains(hasDepartment.Id), 'Tender with department must be excluded');
    }

    @IsTest
    static void testFinish_runsWithoutErrors() {
        PolymerHDPEBatch batch = newBatch();

        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        System.assertEquals(0, PolymerHDPEBatch.dmlErrors.size(), 'No DML errors expected');
    }

    // =====================================================================
    // Step 1 (Prompt Template)
    // =====================================================================
    @IsTest
    static void testStep1Skipped_whenNoDescriptionAndNoSummary() {
        Tender__c t = createTender();

        Tender__c r = executeOne(t.Id, newBatch());

        assertSummaryContains(r, 'STEP 1 SKIPPED');
    }

    @IsTest
    static void testStep1Fired_whenDescriptionPresent() {
        Tender__c t = createTender('Supply of HDPE pipes and polymer granules for the plant.');

        Tender__c r = executeOne(t.Id, newBatch());

        // Outcome of the prompt call depends on the org, but Step 1 must have run
        // and a department must always be resolved (Step 1 match, or Step 2 / default).
        assertSummaryContains(r, 'STEP 1');
        System.assert(
            r.Department_Name__c == 'HDPE' || r.Department_Name__c == 'Polymer',
            'Department must be resolved, was: ' + r.Department_Name__c
        );
        System.assertNotEquals(null, r.Polymer_HDPE_Stage_Check__c);
    }

    // =====================================================================
    // Config / unexpected errors
    // =====================================================================
    /*@IsTest
    static void testConfigError_whenKeywordMapEmpty() {
        Tender__c t = createTender();
        PolymerHDPEBatch b = newBatch();
        b.keywordMap = new Map<String, PolymerHDPEKeywordService.KeywordConfig>();

        Tender__c r = executeOne(t.Id, b);

        assertOutcome(r, 'HDPE', false, 'Failed - Config Error');
        assertSummaryContains(r, 'Could not load');
    }*/

    @IsTest
    static void testConfigError_whenKeywordMapNull() {
        Tender__c t = createTender();
        PolymerHDPEBatch b = newBatch();
        b.keywordMap = null;

        Tender__c r = executeOne(t.Id, b);

        assertOutcome(r, 'HDPE', false, 'Failed - Config Error');
    }

    @IsTest
    static void testUnexpectedError_isCaughtAndDefaultsToHdpe() {
        Tender__c t = createTender();

        // Query only Id + Name: reading Tender_Description__c etc. throws
        // SObjectException inside the batch's try/catch.
        Tender__c partial = [SELECT Id, Name FROM Tender__c WHERE Id = :t.Id];
        PolymerHDPEBatch b = newBatch();

        Test.setMock(HttpCalloutMock.class, new PolymerHDPEMock());
        Test.startTest();
        b.execute(null, new List<Tender__c>{ partial });
        Test.stopTest();

        Tender__c r = reload(t.Id);
        assertOutcome(r, 'HDPE', false, 'Failed - Unexpected Error');
        assertSummaryContains(r, 'UNEXPECTED ERROR');
    }

    // =====================================================================
    // Step 2 - document handling
    // =====================================================================
    @IsTest
    static void testNoDocuments() {
        Tender__c t = createTender();

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', false, 'Failed - No Documents');
        assertSummaryContains(r, 'No Tender_Docoment_Details__c child records found');
    }

    @IsTest
    static void testUnsupportedFile() {
        Tender__c t = createTender();
        createDocument(t.Id, 'Tender.zip', 'ZIP', 'https://unsupported.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', true, 'No Supported Files');
        assertSummaryContains(r, 'SKIPPED "Tender.zip"');
    }

    @IsTest
    static void testBlankDownloadUrl() {
        Tender__c t = createTender();
        createDocument(t.Id, 'BlankUrl.pdf', 'PDF', null);

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', true, 'Checked - No Match');
        assertSummaryContains(r, 'are blank');
    }

    @IsTest
    static void testDownloadHttpError() {
        Tender__c t = createTender();
        createDocument(t.Id, 'Download500.pdf', 'PDF', 'https://download500.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', false, 'Failed - Will Retry');
        assertSummaryContains(r, 'HTTP Status: 500');
    }

    @IsTest
    static void testDownloadException() {
        Tender__c t = createTender();
        createDocument(t.Id, 'DownloadException.pdf', 'PDF', 'https://downloadException.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', false, 'Failed - Will Retry');
        assertSummaryContains(r, 'Download exception for test');
    }

    @IsTest
    static void testEmptyFile() {
        Tender__c t = createTender();
        createDocument(t.Id, 'EmptyFile.pdf', 'PDF', 'https://emptyfile.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', false, 'Failed - Will Retry');
        assertSummaryContains(r, 'Downloaded content is empty');
    }

    @IsTest
    static void testLargeFile_skippedByHeapGuard() {
        Tender__c t = createTender();
        createDocument(t.Id, 'LargeFile.pdf', 'PDF', 'https://largefile.test/file');

        // Run through executeBatch (async heap limit) so the 2MB body fits in the test
        Test.setMock(HttpCalloutMock.class, new PolymerHDPEMock());
        Test.startTest();
        Database.executeBatch(newBatch(), 1);
        Test.stopTest();

        Tender__c r = reload(t.Id);
        assertOutcome(r, 'HDPE', true, 'Checked - No Match');
        assertSummaryContains(r, 'File too large to safely analyze');
    }

    // =====================================================================
    // Step 2 - Gemini results
    // =====================================================================
    @IsTest
    static void testGeminiError() {
        Tender__c t = createTender();
        createDocument(t.Id, 'GEMINI_ERROR_TENDER.pdf', 'PDF', 'https://geminierror.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', false, 'Failed - Will Retry');
        assertSummaryContains(r, 'ERROR analyzing');
    }

    @IsTest
    static void testHDPEMatch() {
        Tender__c t = createTender();
        createDocument(t.Id, 'HDPE_TENDER.pdf', 'PDF', 'https://hdpe.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', true, 'Matched');
        assertSummaryContains(r, 'SUCCESS (Step 2 - Document Analysis)');
    }

    @IsTest
    static void testPolymerMatch() {
        Tender__c t = createTender();
        createDocument(t.Id, 'POLYMER_TENDER.pdf', 'PDF', 'https://polymer.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'Polymer', true, 'Matched');
        assertSummaryContains(r, 'Department = "Polymer"');
    }

    @IsTest
    static void testNoMatch() {
        Tender__c t = createTender();
        createDocument(t.Id, 'NO_MATCH_TENDER.pdf', 'PDF', 'https://nomatch.test/file');

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', true, 'Checked - No Match');
        assertSummaryContains(r, 'No match in');
    }

    // Two matching files: the loop must stop after the first match
    @IsTest
    static void testStopsAfterFirstMatch() {
        Tender__c t = createTender();
        insert new List<Tender_Docoment_Details__c>{
            buildDocument(t.Id, 'POLYMER_TENDER_1.pdf', 'PDF', 'https://polymer.test/1'),
            buildDocument(t.Id, 'POLYMER_TENDER_2.pdf', 'PDF', 'https://polymer.test/2')
        };

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'Polymer', true, 'Matched');
        Integer readCount = r.Reading_Polymer_HDPE_summary__c.split('READING "').size() - 1;
        System.assertEquals(1, readCount, 'Only the first matching file should be analyzed');
    }

    // One file without match + one with match -> Polymer wins regardless of order
    @IsTest
    static void testNoMatchFileThenMatchingFile() {
        Tender__c t = createTender();
        insert new List<Tender_Docoment_Details__c>{
            buildDocument(t.Id, 'NO_MATCH_TENDER.pdf', 'PDF', 'https://nomatch.test/file'),
            buildDocument(t.Id, 'POLYMER_TENDER.pdf', 'PDF', 'https://polymer.test/file')
        };

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'Polymer', true, 'Matched');
    }

    // A failed download plus a matching file: the match wins
    @IsTest
    static void testDownloadErrorFileAndMatchingFile() {
        Tender__c t = createTender();
        insert new List<Tender_Docoment_Details__c>{
            buildDocument(t.Id, 'Download500.pdf', 'PDF', 'https://download500.test/file'),
            buildDocument(t.Id, 'HDPE_TENDER.pdf', 'PDF', 'https://hdpe.test/file')
        };

        Tender__c r = executeOne(t.Id, newBatch());

        assertOutcome(r, 'HDPE', true, 'Matched');
    }

    // =====================================================================
    // Owner assignment
    // =====================================================================
    /*@IsTest
    static void testOwnerAssignedFromOwnerMap() {
        // Create a second active user (System.runAs avoids mixed-DML errors)
        User other;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
            String uniq = String.valueOf(Crypto.getRandomInteger()).replace('-', 'x');
            other = new User(
    Alias = 'own' + uniq.left(4),
    Email = 'owner' + uniq + '@example.com',
    EmailEncodingKey = 'UTF-8',
    LastName = 'OwnerTest',
    LanguageLocaleKey = 'en_US',
    LocaleSidKey = 'en_US',
    ProfileId = p.Id,
    TimeZoneSidKey = 'Asia/Kolkata',
    Username = 'owner' + uniq + '@example.com.test',
    Department = 'Polymer'      // <-- add this so the validation rule passes
);
            insert other;
        }

        Tender__c t = createTender();
        createDocument(t.Id, 'POLYMER_TENDER.pdf', 'PDF', 'https://polymer.test/file');

        PolymerHDPEBatch b = newBatch();
        b.ownerMap.put('Polymer', other.Id);

        Tender__c r = executeOne(t.Id, b);

        assertOutcome(r, 'Polymer', true, 'Matched');
        System.assertEquals(other.Id, r.OwnerId, 'Owner must come from ownerMap for Polymer');
    }
*/
    @IsTest
    static void testOwnerUnchanged_whenDepartmentNotInOwnerMap() {
        Tender__c t = createTender();
        createDocument(t.Id, 'POLYMER_TENDER.pdf', 'PDF', 'https://polymer.test/file');
        Id originalOwner = [SELECT OwnerId FROM Tender__c WHERE Id = :t.Id].OwnerId;

        // ownerMap is empty (newBatch clears it)
        Tender__c r = executeOne(t.Id, newBatch());

        System.assertEquals(originalOwner, r.OwnerId, 'Owner must not change without a mapping');
    }

    // =====================================================================
    // DML failure + summary truncation
    // =====================================================================
    /*@IsTest
    static void testDmlFailure_isCollected() {
        Tender__c t = createTender();
        Tender__c scope = getTenderWithDocuments(t.Id);
        delete t; // update of a deleted record fails -> hits the DML error branch

        PolymerHDPEBatch b = newBatch();
        Test.setMock(HttpCalloutMock.class, new PolymerHDPEMock());

        Test.startTest();
        b.execute(null, new List<Tender__c>{ scope });
        Test.stopTest();

        System.assertEquals(1, PolymerHDPEBatch.dmlErrors.size(), 'One DML error expected');
        System.assert(
            PolymerHDPEBatch.dmlErrors[0].contains(String.valueOf(t.Id)),
            'Error should reference the tender Id'
        );
    }
*/
   /* @IsTest
    static void testSummaryIsTruncated_whenTooLong() {
        Tender__c t = createTender();

        // Many unsupported files -> one long "SKIPPED ..." line each
        Integer nameLen = Tender_Docoment_Details__c.Name__c.getDescribe().getLength();
        nameLen = (nameLen < 20) ? 20 : Math.min(nameLen, 200);
        Integer docCount = (SUMMARY_MAX_LEN / (nameLen + 40)) + 50;

        String fileName = 'a'.repeat(nameLen - 4) + '.zip';
        List<Tender_Docoment_Details__c> docs = new List<Tender_Docoment_Details__c>();
        for (Integer i = 0; i < docCount; i++) {
            docs.add(buildDocument(t.Id, fileName, 'ZIP', 'https://unsupported.test/' + i));
        }
        insert docs;

        Tender__c r = executeOne(t.Id, newBatch());

        System.assertEquals('No Supported Files', r.Polymer_HDPE_Stage_Check__c);
        System.assert(
            r.Reading_Polymer_HDPE_summary__c.length() <= SUMMARY_MAX_LEN,
            'Summary must fit the long text area, length: ' + r.Reading_Polymer_HDPE_summary__c.length()
        );
        assertSummaryContains(r, '[TRUNCATED - see logs]');
    }
*/
    // =====================================================================
    // Full batch run: start() -> execute() -> finish()
    // =====================================================================
    @IsTest
    static void testFullBatchExecution() {
        Tender__c t = createTender();
        createDocument(t.Id, 'HDPE_TENDER_BATCH.pdf', 'PDF', 'https://batch.test/file');

        Test.setMock(HttpCalloutMock.class, new PolymerHDPEMock());
        Test.startTest();
        Database.executeBatch(newBatch(), 1);
        Test.stopTest();

        Tender__c r = reload(t.Id);
        assertOutcome(r, 'HDPE', true, 'Matched');
        assertSummaryContains(r, 'Polymer/HDPE Check for Tender');
        System.assertEquals(0, PolymerHDPEBatch.dmlErrors.size(), 'No DML errors expected');
    }
    
    private static void assertOutcome(Tender__c r, String dept, Boolean checked, String stage) {
        String info = ' | DML errors: ' + PolymerHDPEBatch.dmlErrors;
        System.assertEquals(dept, r.Product_Name__c, 'Product_Name__c' + info);
        System.assertEquals(dept, r.Department_Name__c, 'Department_Name__c' + info);
        System.assertEquals(checked, r.Is_checked_Polymer_HDPE__c, 'Is_checked_Polymer_HDPE__c' + info);
        System.assertEquals(stage, r.Polymer_HDPE_Stage_Check__c, 'Polymer_HDPE_Stage_Check__c' + info);
        System.assertNotEquals(null, r.Reading_Polymer_HDPE_summary__c, 'Summary must be written' + info);
    }
    
    
}