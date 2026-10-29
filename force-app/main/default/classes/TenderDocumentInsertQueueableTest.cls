@isTest
private without sharing class TenderDocumentInsertQueueableTest {
    
    // Helper - creates a document detail record without an Id, ready for insert.
    private static Tender__c createParentTender() {
        Tender__c t = new Tender__c();
        insert as system t;
        return t;
    }
    
    private static Tender_Docoment_Details__c buildDoc(Id tenderId) {
        Tender_Docoment_Details__c doc = new Tender_Docoment_Details__c();
        doc.Tender__c            = tenderId;
        doc.Document_Id__c       = '12345';
        doc.Name__c              = 'Test Document';
        doc.Type__c              = 'PDF';
        doc.Download_URL_Text__c = 'https://example.com/test.pdf';
        return doc;
    }
    
    private static Tender_Docoment_Details__c buildDocWithFakeParent() {
        String tenderPrefix = Tender__c.SObjectType.getDescribe().getKeyPrefix();
        Id fakeTenderId = (Id) (tenderPrefix + '000000000000');
        
        Tender_Docoment_Details__c doc = new Tender_Docoment_Details__c();
        doc.Tender__c            = fakeTenderId;
        doc.Document_Id__c       = '99999';
        doc.Name__c              = 'Invalid Parent Document';
        doc.Type__c              = 'PDF';
        doc.Download_URL_Text__c = 'https://example.com/invalid.pdf';
        return doc;
    }
    
    @isTest
    static void testNullDocuments() {
        Test.startTest();
        TenderDocumentInsertQueueable q =
            new TenderDocumentInsertQueueable(null, 0, 8000, 'Test Product');
        q.execute(null);
        Test.stopTest();
        System.assert(true, 'Null list should return early without error');
    }
    
    @isTest
    static void testEmptyDocuments() {
        Test.startTest();
        TenderDocumentInsertQueueable q =
            new TenderDocumentInsertQueueable(new List<Tender_Docoment_Details__c>(), 0, 8000, 'Test Product');
        q.execute(null);
        Test.stopTest();
        System.assert(true, 'Empty list should return early without error');
    }
    
    @isTest
    static void testStartIndexBeyondSize() {
        Tender__c parent = createParentTender();
        List<Tender_Docoment_Details__c> docs = new List<Tender_Docoment_Details__c>{
            buildDoc(parent.Id)
                };
                    
                    Test.startTest();
        TenderDocumentInsertQueueable q =
            new TenderDocumentInsertQueueable(docs, 5, 8000, 'Test Product');
        q.execute(null);
        Test.stopTest();
        
        System.assertEquals(
            0,
            [SELECT COUNT() FROM Tender_Docoment_Details__c],
            'No document should be inserted when startIndex is beyond the list size'
        );
    }
    
    @isTest
    static void testSuccessfulInsert_SingleChunk() {
        Tender__c parent = createParentTender();
        List<Tender_Docoment_Details__c> docs = new List<Tender_Docoment_Details__c>{
            buildDoc(parent.Id),
                buildDoc(parent.Id)
                };
                    
                    Test.startTest();
        TenderDocumentInsertQueueable q =
            new TenderDocumentInsertQueueable(docs, 0, 8000, 'Test Product');
        q.execute(null);
        Test.stopTest();
        
        System.assertEquals(
            2,
            [SELECT COUNT() FROM Tender_Docoment_Details__c],
            'Both documents should be inserted successfully in a single chunk'
        );
    }
    
    @isTest
    static void testSuccessfulInsert_MoreRecordsRemain() {
        Tender__c parent = createParentTender();
        List<Tender_Docoment_Details__c> docs = new List<Tender_Docoment_Details__c>{
            buildDoc(parent.Id),
                buildDoc(parent.Id),
                buildDoc(parent.Id)
                };
                    
                    Test.startTest();
        TenderDocumentInsertQueueable q =
            new TenderDocumentInsertQueueable(docs, 0, 2, 'Test Product');
        q.execute(null);
        Test.stopTest();
        
        System.assertEquals(
            2,
            [SELECT COUNT() FROM Tender_Docoment_Details__c],
            'Only the first chunk (2 records) should be inserted in this execute() call'
        );
    }
    
    
    
    @isTest
    static void testInsertPartialFailure_RowLevel() {
        Tender__c parent = createParentTender();
        Tender_Docoment_Details__c validDoc = buildDoc(parent.Id);
        Tender_Docoment_Details__c invalidDoc = buildDocWithFakeParent();
        
        List<Tender_Docoment_Details__c> docs = new List<Tender_Docoment_Details__c>{
            validDoc,
                invalidDoc
                };
                    
                    Test.startTest();
        TenderDocumentInsertQueueable q =
            new TenderDocumentInsertQueueable(docs, 0, 8000, 'Test Product');
        q.execute(null);
        Test.stopTest();
        
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Tender_Docoment_Details__c],
            'Only the valid document should be inserted; the fake-parent row should fail at row level'
        );
    }
    
    @isTest
    static void testInsertFailure_ExceptionPath() {
        Tender__c parent = createParentTender();
        
        List<Tender_Docoment_Details__c> docs = new List<Tender_Docoment_Details__c>{
            buildDoc(parent.Id),
                null   // forces Database.insert to throw synchronously -> hits the catch block
                };
                    
                    Test.startTest();
        TenderDocumentInsertQueueable q =
            new TenderDocumentInsertQueueable(docs, 0, 8000, 'Test Product');
        q.execute(null);
        Test.stopTest();
        
        System.assert(true, 'A null element in the chunk should cause Database.insert to throw and be handled by the catch block');
    }
}