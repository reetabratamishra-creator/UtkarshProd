public with sharing class POResponseParser {

    public static void parseAndSave(Id recordId, String rawJson) {
        PO_Line_Items__c rec = new PO_Line_Items__c(Id = recordId);

        // Clean common LLM wrapping artifacts
        String cleaned = rawJson == null ? '' : rawJson
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .replaceAll('`', '')
            .trim();

        // Quick sanity check: does it even look like JSON?
        if (!cleaned.startsWith('{')) {
            rec.Status__c = 'Failed';
            rec.Error_Message__c = 'Model did not return JSON. Likely the file was not received by the prompt. Response: ' + cleaned.abbreviate(500);
            rec.Raw_JSON_Response__c = rawJson;
            update rec;
            return;
        }

        try {
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(cleaned);

            rec.PO_Number__c = getStr(data, 'po_number');
            rec.PO_Date__c = getStr(data, 'po_date');
            rec.Basic_Material_Value__c = getStr(data, 'basic_material_value');
            rec.Freight_Details__c = getStr(data, 'freight_details');
            rec.Payment_Terms__c = getStr(data, 'payment_terms');
            rec.Per_Unit_Rate__c = getStr(data, 'per_unit_rate');
            rec.Quantity__c = getStr(data, 'Quantity');
            rec.Material_Value_Calculated__c = getStr(data, 'material_value_calculated');
            
            String amountValue = getStr(data, 'amount');
            if (!String.isBlank(amountValue)) {
            amountValue = amountValue.replace(',', '').trim();
            try {
             rec.Amount__c = Decimal.valueOf(amountValue);
            } catch (Exception e) {
              System.debug('Unable to parse amount: ' + amountValue + '. Error: ' + e.getMessage());
            }
           }

          

            rec.Payment_Mode__c = getStr(data, 'payment_mode');
            rec.Delivery_Schedule__c = getStr(data, 'delivery_schedule');
            rec.Delivery_Location__c = getStr(data, 'delivery_location');
            rec.Notes_on_Extraction__c = getStr(data, 'Notes_on_extraction');
            rec.Raw_JSON_Response__c = rawJson;
            //rec.Status__c = 'Completed';
            rec.Processed_Date__c = System.now();
            Boolean manualReviewRequired =
            isMissing(rec.PO_Number__c)
            || isMissing(rec.PO_Date__c)
            || rec.Amount__c == null;

           if (manualReviewRequired) {
           rec.Status__c = 'Manual Review Required';
         } else {
         rec.Status__c = 'Completed';
        }

            update rec;

        } catch (Exception e) {
            rec.Status__c = 'Failed';
            rec.Error_Message__c = 'Parsing failed: ' + e.getMessage();
            rec.Raw_JSON_Response__c = rawJson;
            update rec;
        }
    }

    private static String getStr(Map<String, Object> data, String key) {
        if (data.containsKey(key) && data.get(key) != null) {
            return String.valueOf(data.get(key));
        }
        return null;
    }

    private static Boolean isMissing(String value) {

    if (String.isBlank(value)) {
        return true;
    }

    String normalized = value.trim().toLowerCase();

    return normalized.contains('not found')
        || normalized.contains('not mentioned')
        || normalized.contains('not available');
}
}