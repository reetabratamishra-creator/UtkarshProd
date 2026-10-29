public class QfrPdfController {
    public String enquiryNumber { get; set; }
    public List<Map<String, String>> tableData { get; set; }
    public String specialNotes { get; set; }

    public QfrPdfController(ApexPages.StandardController controller) {
        String quoteId = controller.getId();
        tableData = new List<Map<String, String>>();
        specialNotes = '';
        enquiryNumber = '';
        Quote q = null;

        // 1. ALWAYS fetch Quote details if ID is available to set the Enquiry Number
        if (String.isNotBlank(quoteId)) {
            q = [SELECT Id, Quote_Reference__c, Quote_Value__c FROM Quote WHERE Id = :quoteId LIMIT 1];
            // Map the Enquiry Number to the Quote Reference field
            enquiryNumber = q.Quote_Reference__c != null ? q.Quote_Reference__c : ''; 
        }

        // 2. Check if raw JSON data was passed directly via URL parameter
        String rawJsonData = ApexPages.currentPage().getParameters().get('data');

        if (String.isNotBlank(rawJsonData)) {
            try {
                // Decode the URL-encoded JSON string
                rawJsonData = EncodingUtil.urlDecode(rawJsonData, 'UTF-8');
                List<Object> rows = (List<Object>) JSON.deserializeUntyped(rawJsonData);
                
                for (Object rowObj : rows) {
                    Map<String, Object> rowMap = (Map<String, Object>) rowObj;
                    
                    if (rowMap.get('id') == 'special_notes') {
                        specialNotes = (String) rowMap.get('specialNotes');
                    } else {
                        Map<String, String> r = new Map<String, String>();
                        r.put('slNo', rowMap.get('slNo') != null ? String.valueOf(rowMap.get('slNo')) : '');
                        r.put('description', rowMap.get('description') != null ? String.valueOf(rowMap.get('description')) : '');
                        r.put('specification', rowMap.get('specification') != null ? String.valueOf(rowMap.get('specification')) : '');
                        r.put('requirement', rowMap.get('requirement') != null ? String.valueOf(rowMap.get('requirement')) : '');
                        tableData.add(r);
                    }
                }
            } catch (Exception e) {
                System.debug('Error parsing direct JSON payload: ' + e.getMessage());
            }
        }

        // 3. Fallback to Quote record if no URL parameter was provided
        if (tableData.isEmpty() && q != null && String.isNotBlank(q.Quote_Value__c)) {
            Map<String, Object> parsedData = (Map<String, Object>) JSON.deserializeUntyped(q.Quote_Value__c);
            if (parsedData.containsKey('_pebQFRData')) {
                List<Object> rows = (List<Object>) parsedData.get('_pebQFRData');
                for (Object rowObj : rows) {
                    Map<String, Object> rowMap = (Map<String, Object>) rowObj;
                    if (rowMap.get('id') == 'special_notes') {
                        specialNotes = (String) rowMap.get('specialNotes');
                    } else {
                        Map<String, String> r = new Map<String, String>();
                        r.put('slNo', rowMap.get('slNo') != null ? String.valueOf(rowMap.get('slNo')) : '');
                        r.put('description', rowMap.get('description') != null ? String.valueOf(rowMap.get('description')) : '');
                        r.put('specification', rowMap.get('specification') != null ? String.valueOf(rowMap.get('specification')) : '');
                        r.put('requirement', rowMap.get('requirement') != null ? String.valueOf(rowMap.get('requirement')) : '');
                        tableData.add(r);
                    }
                }
            }
        }
    }
}