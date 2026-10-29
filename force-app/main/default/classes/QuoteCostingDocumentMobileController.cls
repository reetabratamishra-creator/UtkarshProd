/**
 * QuoteCostingDocumentMobileController — Deepanjan (17th July 2026)
 *
 * Mobile-only export path for quoteExcelGenerator. The Salesforce mobile app's
 * webview cannot window.open a VF page (blocked/blank) and rendering the VF
 * page in an iframe was crash-reloading the app, so on phones the LWC calls
 * this instead: render the same VF page server-side, save the result as a
 * Salesforce File linked to the quote, and return the ContentDocumentId so the
 * LWC can open the app's NATIVE file previewer (which has download/share).
 *
 * Desktop never calls this class.
 *
 * Notes:
 *  - getContent()/getContentAsPDF() count as callouts (API 44+), so they run
 *    BEFORE any DML in this transaction — order below is deliberate.
 *  - vfPagePath is validated against /apex/<Name> before use; the id parameter
 *    is appended server-side from the quoteId argument, so the client can never
 *    make this fetch an arbitrary URL.
 */

public class QuoteCostingDocumentMobileController {

    
    @AuraEnabled
    public static Map<String, String> saveQuoteDocumentToFiles(Id quoteId, String vfPagePath, String format) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
 
        // ── validate the VF path shape: "/apex/PageName" only ────────────────
        String path = vfPagePath == null ? '' : vfPagePath.trim();
        if (!Pattern.matches('^/apex/[A-Za-z0-9_]+$', path)) {
            throw new AuraHandledException('Invalid document page.');
        }
 
        // ── render the page (callout — must precede all DML) ─────────────────
        PageReference pg = new PageReference(path + '?id=' + String.valueOf(quoteId));
        Blob body;
        try {
            if (Test.isRunningTest()) {
                // getContent* is not supported in test context
                body = Blob.valueOf('TEST-DOCUMENT-BODY');
            } else if (format == 'pdf') {
                body = pg.getContentAsPDF();
            } else {
                body = pg.getContent();
            }
        } catch (Exception e) {
            throw new AuraHandledException('Document rendering failed: ' + e.getMessage());
        }
 
        // ── file name: QuoteNumber + revision when available ─────────────────
        String ext = format == 'excel' ? 'xls' : (format == 'word' ? 'doc' : 'pdf');
        String quoteNumber = String.valueOf(quoteId);
        Decimal revisionNo = 0;
        try {
            // Revision_No__c may not exist in every org this ships to; the
            // dynamic query keeps the class deployable either way.
            SObject q = Database.query(
                'SELECT QuoteNumber' +
                (revisionFieldExists() ? ', Revision_No__c' : '') +
                ' FROM Quote WHERE Id = :quoteId LIMIT 1');
            quoteNumber = (String) q.get('QuoteNumber');
            if (revisionFieldExists() && q.get('Revision_No__c') != null) {
                revisionNo = (Decimal) q.get('Revision_No__c');
            }
        } catch (Exception ignored) { /* fall back to the Id-based name */ }
 
        String title = 'Quote_' + quoteNumber
            + (revisionNo > 0 ? '_R' + String.valueOf(revisionNo.intValue()) : '')
            + '_' + Datetime.now().format('yyyyMMdd_HHmm');
 
        // ── save as a PRIVATE file (NOT linked to the quote): the finalize flow
        // already stores the PDFs on the quote, so linking here would duplicate.
        // Deepanjan (18th July 2026)
        ContentVersion cv = new ContentVersion(
            Title        = title,
            PathOnClient = title + '.' + ext,
            VersionData  = body
        );
        insert cv;

        return finishSave(cv.Id);
    }

    /**
     * Shared tail for both save methods — Deepanjan (18th July 2026).
     * Looks up the ContentDocumentId and TRIES to create a ContentDistribution:
     * its ContentDownloadUrl, opened in the phone's system browser, triggers a
     * real browser download straight into device storage (the in-app "download"
     * arrow only saves an offline copy INSIDE Salesforce). If Content Deliveries
     * are off in the org, downloadUrl comes back null and the LWC falls back to
     * the native previewer.
     */
    private static Map<String, String> finishSave(Id contentVersionId) {
        ContentVersion cv = [SELECT ContentDocumentId, Title
                             FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        String downloadUrl = null;
        String publicUrl = null;
        try {
            ContentDistribution dist = new ContentDistribution(
                Name = cv.Title.left(255),
                ContentVersionId = contentVersionId,
                PreferencesAllowOriginalDownload = true,
                PreferencesAllowViewInBrowser = true,
                PreferencesNotifyOnVisit = false,
                // Per Deepanjan (18th July 2026): links do NOT expire. Note the
                // trade-off - anyone who ever gets a link can use it forever.
                PreferencesExpires = false
            );
            insert dist;
            dist = [SELECT ContentDownloadUrl, DistributionPublicUrl
                    FROM ContentDistribution WHERE Id = :dist.Id LIMIT 1];
            downloadUrl = dist.ContentDownloadUrl;
            publicUrl = dist.DistributionPublicUrl;
        } catch (Exception e) {
            // Content Deliveries disabled or perms missing — previewer fallback.
        }
        return new Map<String, String>{
            'contentDocumentId' => cv.ContentDocumentId,
            'downloadUrl' => downloadUrl,
            // Short https://<domain>/a/<token> link - the SF mobile app's
            // standard__webPage validator rejects the long query-string
            // ContentDownloadUrl ("Page doesn't exist"), but accepts this one.
            // The page it opens has its own Download button.
            // Deepanjan (18th July 2026)
            'publicUrl' => publicUrl
        };
    }
 
    private static Boolean revisionFieldExists() {
        return Schema.SObjectType.Quote.fields.getMap().containsKey('revision_no__c');
    }
 
    /**
     * Saves a CLIENT-GENERATED document (e.g. the SheetJS cost sheet, built
     * entirely in the browser) as a File on the record and returns the
     * ContentDocumentId for the native previewer. Used by costSheetGenerator's
     * mobile branch - the browser <a download> route the desktop uses is
     * silently swallowed by the mobile app's webview. Deepanjan (17th July 2026)
     */
    @AuraEnabled
    public static Map<String, String> saveGeneratedFile(Id recordId, String base64Data, String fileName) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('No file content received.');
        }
        // LWC->Apex payloads cap out around 4 MB; fail with a clear message
        // instead of a generic limit error. 5.4M base64 chars ≈ 4 MB binary.
        if (base64Data.length() > 5400000) {
            throw new AuraHandledException('The generated file is too large to save from the mobile app.');
        }
        String safeName = String.isBlank(fileName) ? 'Document_' + Datetime.now().format('yyyyMMdd_HHmm') + '.bin'
                                                   : fileName.replaceAll('[\\\\/:*?"<>|]', '_');
        Blob body;
        try {
            body = EncodingUtil.base64Decode(base64Data);
        } catch (Exception e) {
            throw new AuraHandledException('File content is not valid base64.');
        }
 
        // PRIVATE file — not linked to the record, the finalize flow owns the
        // record's own copies. Deepanjan (18th July 2026)
        ContentVersion cv = new ContentVersion(
            Title        = safeName.substringBeforeLast('.'),
            PathOnClient = safeName,
            VersionData  = body
        );
        insert cv;

        return finishSave(cv.Id);
    }
}