public with sharing class PromptTemplateFlowService {
    
    private static final String TEMPLATE_API_NAME = 'Purchase_Order_Key_Data_Extraction';

    public class FlowRequest {
        @InvocableVariable(required=true)
        public List<Id> contentVersionIds;
    }

    public class FlowResult {
        @InvocableVariable
        public String extractedText;
        @InvocableVariable
        public Boolean isSuccess;
        @InvocableVariable
        public String errorMessage;
        @InvocableVariable
        public String poNumber;
        @InvocableVariable
        public Date poDate;
        @InvocableVariable
        public Decimal poAmount;
    }

    @InvocableMethod(label='Run PO Extraction')
    public static List<FlowResult> runExtraction(List<FlowRequest> requests) {
        List<FlowResult> resultsList = new List<FlowResult>();

        for (FlowRequest req : requests) {
            FlowResult result = new FlowResult();

            try {
                Id contentVersionId = req.contentVersionIds[0];

                ContentVersion cv = [
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :contentVersionId
                ];

                Map<String, String> fileMap = new Map<String, String>{
                    'id'   => cv.ContentDocumentId,
                    'type' => 'ContentDocument'
                };

                ConnectApi.WrappedValue fileValue = new ConnectApi.WrappedValue();
                fileValue.value = fileMap;

                Map<String, ConnectApi.WrappedValue> inputParamsMap = new Map<String, ConnectApi.WrappedValue>();
                inputParamsMap.put('Input:File', fileValue);

                ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
                promptInput.inputParams = inputParamsMap;
                promptInput.isPreview = false;
                promptInput.additionalConfig = new ConnectApi.EinsteinLLmAdditionalConfigInput();

                ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
                    ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE_API_NAME, promptInput);

                if (generationsOutput != null && generationsOutput.generations != null && !generationsOutput.generations.isEmpty()) {
                    result.extractedText = generationsOutput.generations[0].text;
                    result.isSuccess = true;

                    // ----  parse JSON text into individual PO fields ----
                    String cleaned = result.extractedText.trim();
                    if (cleaned.startsWith('```')) {
                        cleaned = cleaned.substringAfter('```').replaceFirst('(?i)^json', '');
                        if (cleaned.contains('```')) {
                            cleaned = cleaned.substringBefore('```');
                        }
                        cleaned = cleaned.trim();
                    }

                    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(cleaned);

                    if (parsed.get('po_number') != null) {
                        result.poNumber = String.valueOf(parsed.get('po_number'));
                    }

                    if (parsed.get('po_date') != null) {
                        String dStr = String.valueOf(parsed.get('po_date')).replace('/', '-');
                        List<String> dParts = dStr.split('-');
                        if (dParts.size() == 3) {
                            result.poDate = Date.newInstance(
                                Integer.valueOf(dParts[2]),
                                Integer.valueOf(dParts[1]),
                                Integer.valueOf(dParts[0])
                            );
                        }
                    }

                    if (parsed.get('amount') != null) {
                        String amtStr = String.valueOf(parsed.get('amount')).replaceAll('[^0-9\\.]', '');
                        if (String.isNotBlank(amtStr)) {
                            result.poAmount = Decimal.valueOf(amtStr);
                        }
                    }

                } else {
                    result.isSuccess = false;
                    result.errorMessage = 'No response received from Prompt Template.';
                }

            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = 'Prompt error: ' + e.getMessage();
            }

            resultsList.add(result);
        }

        return resultsList;
    }
}