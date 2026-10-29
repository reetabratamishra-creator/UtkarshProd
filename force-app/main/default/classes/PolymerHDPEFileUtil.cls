public with sharing class PolymerHDPEFileUtil {
    public class SupportCheck {
        public Boolean isSupported;
        public String  mimeType;
        public String  reason; // populated when NOT supported
    }
    public static SupportCheck checkSupport(String fileName) {
        SupportCheck sc = new SupportCheck();
        if (String.isBlank(fileName)) {
            sc.isSupported = false;
            sc.reason      = 'File name is blank/unknown - cannot determine type.';
            return sc;
        }
        String lower = fileName.toLowerCase();
        if (lower.endsWith('.pdf')) {
            sc.isSupported = true;
            sc.mimeType    = 'application/pdf';
        } else if (lower.endsWith('.txt')) {
            sc.isSupported = true;
            sc.mimeType    = 'text/plain';
        } else if (lower.endsWith('.html') || lower.endsWith('.htm')) {
            sc.isSupported = true;
            sc.mimeType    = 'text/html'; // best-effort; not officially documented by Gemini but works in practice
        } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
            sc.isSupported = true;
            sc.mimeType    = 'image/jpeg';
        } else if (lower.endsWith('.png')) {
            sc.isSupported = true;
            sc.mimeType    = 'image/png';
        } else if (lower.endsWith('.zip')) {
            sc.isSupported = false;
            sc.reason      = 'ZIP archives are not sent to Gemini directly (unsupported document type) and are not extracted in this process.';
        } else {
            sc.isSupported = false;
            sc.reason      = 'Unsupported file type for Gemini document analysis (only .pdf, .txt, .html, .jpg, .jpeg, .png are processed).';
        }
        return sc;
    }
}