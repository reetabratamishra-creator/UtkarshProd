/**
 * Coverage for QuoteCostingDocumentMobileController. getContent* is unsupported in
 * test context, so the controller substitutes a fixed blob when
 * Test.isRunningTest() — the assertions here cover validation, file creation,
 * naming, and record linkage. Deepanjan (17th July 2026)
 */
@isTest
private class QuoteCostingDocumentMobileControllerTest {

    private static Id makeQuote() {
        Opportunity opp = new Opportunity(
            Name = 'Doc Test Opp', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30));
        insert opp;
        Quote q = new Quote(Name = 'Doc Test Quote', OpportunityId = opp.Id);
        insert q;
        return q.Id;
    }

    @isTest
    static void savesPdfAndLinksToQuote() {
        Id quoteId = makeQuote();

        Test.startTest();
        Map<String, String> res = QuoteCostingDocumentMobileController.saveQuoteDocumentToFiles(
            quoteId, '/apex/SomeQuotePdfPage', 'pdf');
        Test.stopTest();

        Id docId = (Id) res.get('contentDocumentId');
        System.assertNotEquals(null, docId, 'ContentDocumentId expected');
        // finalize owns the quote's copies - this save must NOT link to the record
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId AND ContentDocumentId = :docId];
        System.assertEquals(0, links.size(), 'File must stay private, not on the quote');
        ContentVersion cv = [
            SELECT PathOnClient FROM ContentVersion
            WHERE ContentDocumentId = :docId AND IsLatest = true LIMIT 1];
        System.assert(cv.PathOnClient.endsWith('.pdf'), 'pdf extension expected');
    }

    @isTest
    static void rejectsBadPath() {
        Id quoteId = makeQuote();
        Boolean threw = false;
        try {
            QuoteCostingDocumentMobileController.saveQuoteDocumentToFiles(
                quoteId, 'https://evil.example/steal', 'pdf');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'non-/apex/ path must be rejected');
    }

    @isTest
    static void excelGetsXlsExtension() {
        Id quoteId = makeQuote();
        Id docId = (Id) QuoteCostingDocumentMobileController.saveQuoteDocumentToFiles(
            quoteId, '/apex/SomeQuoteExcelPage', 'excel').get('contentDocumentId');
        ContentVersion cv = [
            SELECT PathOnClient FROM ContentVersion
            WHERE ContentDocumentId = :docId AND IsLatest = true LIMIT 1];
        System.assert(cv.PathOnClient.endsWith('.xls'), 'xls extension expected');
    }

    @isTest
    static void savesClientGeneratedFile() {
        Id quoteId = makeQuote();
        String b64 = EncodingUtil.base64Encode(Blob.valueOf('FAKE-XLSX-BYTES'));

        Test.startTest();
        Map<String, String> res = QuoteCostingDocumentMobileController.saveGeneratedFile(
            quoteId, b64, 'Cost_Sheet_Test.xlsx');
        Test.stopTest();

        Id docId = (Id) res.get('contentDocumentId');
        System.assertNotEquals(null, docId, 'ContentDocumentId expected');
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :quoteId AND ContentDocumentId = :docId];
        System.assertEquals(0, links.size(), 'File must stay private, not on the quote');
        ContentVersion cv = [
            SELECT PathOnClient FROM ContentVersion
            WHERE ContentDocumentId = :docId AND IsLatest = true LIMIT 1];
        System.assertEquals('Cost_Sheet_Test.xlsx', cv.PathOnClient);
    }

    @isTest
    static void rejectsEmptyGeneratedFile() {
        Id quoteId = makeQuote();
        Boolean threw = false;
        try {
            QuoteCostingDocumentMobileController.saveGeneratedFile(quoteId, '', 'x.xlsx');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'blank content must be rejected');
    }
}