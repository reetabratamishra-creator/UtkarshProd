@IsTest
private class PolymerHDPEFileUtilTest {

    @IsTest
    static void testBlankFileName() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('');
        System.assertEquals(false, result.isSupported);
        System.assertEquals(
            'File name is blank/unknown - cannot determine type.',
            result.reason
        );
        System.assertEquals(null, result.mimeType);
    }

    @IsTest
    static void testNullFileName() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport(null);
        System.assertEquals(false, result.isSupported);
        System.assertEquals(
            'File name is blank/unknown - cannot determine type.',
            result.reason
        );
    }

    @IsTest
    static void testPdfFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.PDF');
        System.assertEquals(true, result.isSupported);
        System.assertEquals('application/pdf', result.mimeType);
        System.assertEquals(null, result.reason);
    }

    @IsTest
    static void testTxtFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.TXT');
        System.assertEquals(true, result.isSupported);
        System.assertEquals('text/plain', result.mimeType);
        System.assertEquals(null, result.reason);
    }

    @IsTest
    static void testHtmlFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.HTML');
        System.assertEquals(true, result.isSupported);
        System.assertEquals('text/html', result.mimeType);
        System.assertEquals(null, result.reason);
    }

    @IsTest
    static void testHtmFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.HTM');
        System.assertEquals(true, result.isSupported);
        System.assertEquals('text/html', result.mimeType);
        System.assertEquals(null, result.reason);
    }

    @IsTest
    static void testJpgFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.JPG');
        System.assertEquals(true, result.isSupported);
        System.assertEquals('image/jpeg', result.mimeType);
        System.assertEquals(null, result.reason);
    }

    @IsTest
    static void testJpegFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.JPEG');
        System.assertEquals(true, result.isSupported);
        System.assertEquals('image/jpeg', result.mimeType);
        System.assertEquals(null, result.reason);
    }

    @IsTest
    static void testPngFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.PNG');
        System.assertEquals(true, result.isSupported);
        System.assertEquals('image/png', result.mimeType);
        System.assertEquals(null, result.reason);
    }

    @IsTest
    static void testZipFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.ZIP');
        System.assertEquals(false, result.isSupported);
        System.assertEquals(
            'ZIP archives are not sent to Gemini directly (unsupported document type) and are not extracted in this process.',
            result.reason
        );
        System.assertEquals(null, result.mimeType);
    }

    @IsTest
    static void testUnsupportedFile() {
        PolymerHDPEFileUtil.SupportCheck result =
            PolymerHDPEFileUtil.checkSupport('Tender.XLSX');
        System.assertEquals(false, result.isSupported);
        System.assertEquals(
            'Unsupported file type for Gemini document analysis (only .pdf, .txt, .html, .jpg, .jpeg, .png are processed).',
            result.reason
        );
        System.assertEquals(null, result.mimeType);
    }
}