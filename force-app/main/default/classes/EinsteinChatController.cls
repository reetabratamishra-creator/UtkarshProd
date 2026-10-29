/**
* @description
* Apex controller that handles AI chat session management for Einstein AI Agent using REST APIs.
* It supports:
*  - Starting a new chat session
*  - Sending messages to an existing session
*  - Fetching configuration metadata
*  - Returning predefined language and UI texts from custom metadata
* 
* Dependencies:
*  - Custom_Agent_Configuration__mdt (Custom Metadata Type for agent config)
*  - EinsteinAuthService (handles token authentication)
* Test class - EinsteinChatControllerTest
* Author - Reetabrata
*/

public class EinsteinChatController {
    /**
* Starts a new chat session with Einstein AI Agent.
*
* @param AgentId Optional custom Agent ID; if not provided, default is taken from CMDT.
* @return Map containing `sessionId` and initial `message` from the agent.
* @throws AuraHandledException if API call fails or configuration is invalid.
*/
    
    @AuraEnabled
    public static Map<String, String> startChatSession(String AgentId , String OppID) {
        // Load and validate config
        // 
        System.debug('Opportunity Id'+OppID);
        Custom_Agent_Configuration__mdt config = getValidatedConfig();
        String accessToken = EinsteinAuthService.getAccessToken();
        
        // Determine agent ID
        String AgentforceAgentId = String.isNotBlank(AgentId) ? AgentId : config.Agentforce_Agent_ID__c;
        
        // 2. CAPTURE THE TRUE LOGGED-IN USER DETAILS
        Id currentUserId = UserInfo.getUserId();
        String realUsername = UserInfo.getUserName();
        Id profileId = UserInfo.getProfileId();
        String realProfileName = [SELECT Name FROM Profile WHERE Id = :profileId LIMIT 1].Name;
        User currentUser = [SELECT Department FROM User WHERE Id = :currentUserId LIMIT 1];
        // Use a fallback just in case the user's department field is blank in Salesforce
        String realDepartment = String.isNotBlank(currentUser.Department) ? currentUser.Department : 'Not Assigned';
        
        // 3. DEFINE CONTEXT VARIABLES FOR THE AGENT API
        List<Map<String, Object>> agentContextVariables = new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'LoggedIn_Username',
                    'type' => 'Text',
                    'value' => realUsername
                    },
                        new Map<String, Object>{
                            'name' => 'LoggedIn_ProfileName',
                                'type' => 'Text',
                                'value' => realProfileName
                                },
                                    new Map<String, Object>{
                                        'name' => 'User_DepartmentName',
                                            'type' => 'Text',
                                            'value' => realDepartment
                                            },
                                                new Map<String, Object>{
                                                    'name' => 'Loggedin_UserId',
                                                        'type' => 'Text',
                                                        'value' => currentUserId
                                                        },
                                                            new Map<String, Object>{
                                                                'name' => 'OpportunityId',
                                                                    'type' => 'Text',
                                                                    'value' => OppID
                                                                    }
        };
            
            // Prepare HTTP request for session creation
            HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Api_Base_URL__c + '/einstein/ai-agent/v1/agents/' + AgentforceAgentId + '/sessions');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        
        // Generate unique session key
        String uuid = String.valueOf(UUID.randomUUID());
        
        // Create request body
        String body = JSON.serialize(new Map<String, Object>{
            'externalSessionKey' => uuid,
                'instanceConfig' => new Map<String, String>{
                    'endpoint' => config.Domain_URL__c
                        },
                            'streamingCapabilities' => new Map<String, Object>{
                                'chunkTypes' => new List<String>{ 'Text' }
                            },
                                'bypassUser' => true,
                                'variables' => agentContextVariables
                                });
        req.setBody(body);
        
        // Execute HTTP callout
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Parse and return response
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            String sessionId = (String) response.get('sessionId');
            List<Object> messages = (List<Object>) response.get('messages');
            
            String welcomeMsg = 'Hello!';
            if (messages != null && !messages.isEmpty()) {
                Map<String, Object> firstMsg = (Map<String, Object>) messages[0];
                if (firstMsg.containsKey('message')) {
                    welcomeMsg = (String) firstMsg.get('message');
                }
            }
            System.debug('Welcome Messege'+welcomeMsg);
            
            return new Map<String, String>{
                'sessionId' => sessionId,
                    'message' => welcomeMsg
                    };
                        } else {
                            System.debug(LoggingLevel.ERROR, 'Session API failed: ' + res.getStatusCode() + ' | ' + res.getBody());
                            throw new AuraHandledException('Failed to start chat session. Status=' + res.getStatusCode() + ', Body=' + res.getBody());
                        }
    }
    
    
    /**
* Sends a user message to an active Einstein chat session.
*
* @param sessionId ID of the chat session to send message to.
* @param message Text message to send.
* @return The last AI response message.
* @throws AuraHandledException if sessionId or message is missing, or API fails.
*/
    @AuraEnabled
    public static String sendChatMessage(String sessionId, String message) {
        // Validate input
        if (String.isBlank(sessionId)) {
            throw new AuraHandledException('SessionId is required');
        }
        if (String.isBlank(message)) {
            throw new AuraHandledException('Message is required');
        }
        
        // Load config and access token
        Custom_Agent_Configuration__mdt config = getValidatedConfig();
        String accessToken = EinsteinAuthService.getAccessToken();
        
        // Prepare request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Api_Base_URL__c + '/einstein/ai-agent/v1/sessions/' + sessionId + '/messages');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000); // Set timeout to 30 seconds (can go up to 120000 ms)
        
        // Create message payload
        Long sequenceId = DateTime.now().getTime();
        Map<String, Object> messagePayload = new Map<String, Object>{
            'message' => new Map<String, Object>{
                'sequenceId' => sequenceId,
                    'type' => 'Text',
                    'text' => message
                    },
                        'variables' => new List<Object>()
                        };
                            req.setBody(JSON.serialize(messagePayload));
        
        // Call API
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Handle response
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            List<Object> messages = (List<Object>) response.get('messages');
            if (messages != null && !messages.isEmpty()) {
                Map<String, Object> lastMsg = (Map<String, Object>) messages[messages.size() - 1];
                if (lastMsg.containsKey('message')) {
                    return (String) lastMsg.get('message');
                }
            }
            return 'No response message received.';
        } else {
            System.debug(LoggingLevel.ERROR, 'Chat failed: ' + res.getStatusCode() + ' | ' + res.getBody());
            throw new AuraHandledException('Failed to send message. Status=' + res.getStatusCode() + ', Body=' + res.getBody());
        }
    }
    
    
    /**
* Validates that the Custom Metadata is configured correctly.
*
* @return Valid Custom_Agent_Configuration__mdt record.
* @throws AuraHandledException if no valid configuration is found.
*/
    @TestVisible
    private static Custom_Agent_Configuration__mdt getValidatedConfig() {
        List<Custom_Agent_Configuration__mdt> configs = [
            SELECT Api_Base_URL__c, Agentforce_Agent_ID__c, Domain_URL__c
            FROM Custom_Agent_Configuration__mdt
            LIMIT 1
        ];
        
        if (configs.isEmpty()) {
            throw new AuraHandledException('Custom Metadata configuration not found.');
        }
        
        Custom_Agent_Configuration__mdt config = configs[0];
        if (String.isBlank(config.Api_Base_URL__c) ||
            String.isBlank(config.Agentforce_Agent_ID__c) ||
            String.isBlank(config.Domain_URL__c)) {
                throw new AuraHandledException('Custom Metadata is missing required values.');
            }
        
        return config;
    }
    
    /**
* @description Sends user message to Prompt Builder and returns the generated text.
* @param sessionId Currently unused for Prompt Builder, but kept to prevent LWC errors.
* @param message   The text typed by the user in the LWC chat box.
* @return          The AI-generated string from Prompt Builder.
*/
    
    @AuraEnabled
    public static String translateMessegeFromUser(String message) {
        
        String promptTemplateDeveloperName = 'Language_Conversion'; 
        
        try {
            // 2. Prepare the input for the Prompt Builder
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            
            // 3. Map the User's text to the Prompt Template Variable
            // IMPORTANT: 'Input:UserMessage' must match the exact variable name inside your Prompt Builder template!
            ConnectApi.WrappedValue messageValue = new ConnectApi.WrappedValue();
            messageValue.value = message;
            inputParams.put('Input:Source_Text', messageValue);
            
            // 4. Configure hyper-parameters
            promptInput.inputParams = inputParams;
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.numGenerations = 1;
            promptInput.additionalConfig.enablePiiMasking = false;
            // Use standard app name if you haven't defined a custom one
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview'; 
            promptInput.isPreview = false;
            
            // 5. Call the ConnectApi Service
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(promptTemplateDeveloperName, promptInput);
            
            // 6. Extract and return the response to the LWC
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            System.debug('Prompt Builder Output: ' + response.text);
            
            return response.text;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Prompt Builder API failed: ' + e.getMessage());
            throw new AuraHandledException('Failed to generate response from Prompt Builder: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String translateMessegeFromAgent(String message , String selectedLanguage) {
        
        String promptTemplateDeveloperName = 'Language_Convert'; 
        
        try {
            // 2. Prepare the input for the Prompt Builder
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            
            // 3. Map the User's text to the Prompt Template Variable
            // IMPORTANT: 'Input:UserMessage' must match the exact variable name inside your Prompt Builder template!
            ConnectApi.WrappedValue messageValue = new ConnectApi.WrappedValue();
            messageValue.value = message;
            inputParams.put('Input:Messege', messageValue);
            
            ConnectApi.WrappedValue langValue = new ConnectApi.WrappedValue();
            langValue.value = selectedLanguage;
            inputParams.put('Input:Language', langValue);
            
            // 4. Configure hyper-parameters
            promptInput.inputParams = inputParams;
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.numGenerations = 1;
            promptInput.additionalConfig.enablePiiMasking = false;
            // Use standard app name if you haven't defined a custom one
            promptInput.additionalConfig.applicationName = 'PromptBuilderPreview'; 
            promptInput.isPreview = false;
            
            // 5. Call the ConnectApi Service
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(promptTemplateDeveloperName, promptInput);
            
            // 6. Extract and return the response to the LWC
            ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
            System.debug('Prompt Builder Output: ' + response.text);
            
            return response.text;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Prompt Builder API failed: ' + e.getMessage());
            throw new AuraHandledException('Failed to generate response from Prompt Builder: ' + e.getMessage());
        }
        
    }
    
    /**
     * Ends an active Einstein chat session on the server.
     *
     * @param sessionId ID of the chat session to delete.
     */
    @AuraEnabled
    public static void endChatSession(String sessionId) {
        if (String.isBlank(sessionId)) {
            return; // Nothing to delete
        }
        
        try {
            Custom_Agent_Configuration__mdt config = getValidatedConfig();
            String accessToken = EinsteinAuthService.getAccessToken();
            
            HttpRequest req = new HttpRequest();
            // Standard Agentforce endpoint to delete a session
            req.setEndpoint(config.Api_Base_URL__c + '/einstein/ai-agent/v1/sessions/' + sessionId);
            req.setMethod('DELETE');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('x-session-end-reason', 'UserRequest'); // Header requested
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() != 200 && res.getStatusCode() != 204) {
                System.debug(LoggingLevel.ERROR, 'Failed to end session on server: ' + res.getStatusCode() + ' | ' + res.getBody());
            } else {
                System.debug('Session successfully ended on server.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Exception while ending session: ' + e.getMessage());
            throw new AuraHandledException('Failed to end chat session: ' + e.getMessage());
        }
    }
}