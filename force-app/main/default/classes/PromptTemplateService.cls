public with sharing class PromptTemplateService {
    
    private static final String TEMPLATE_API_NAME = 'Purchase_Order_Key_Data_Extraction';
    
    public static String runExtraction(Id contentVersionId) {
        System.debug('===== PromptTemplateService START =====');
        
        try {
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
                return generationsOutput.generations[0].text;
            }
            
            throw new AuraHandledException('No response received from Prompt Template.');
            
        } catch (Exception e) {
            System.debug('⚠️ PromptTemplateService Error: ' + e.getMessage());
            throw new AuraHandledException('Prompt error: ' + e.getMessage());
        }
    }
}