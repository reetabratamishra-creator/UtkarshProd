/**
 * @description
 * Service class responsible for authenticating with the Einstein AI Agent API.
 * It retrieves an OAuth 2.0 access token using client credentials stored in a Custom Metadata Type.
 *
 * Custom Metadata Type used:
 *   - Custom_Agent_Configuration__mdt: Stores client credentials and domain URL.
 *
 * Main Responsibilities:
 *   - Generate a valid access token for API calls.
 *   - Validate configuration values.
 *   - Provide meaningful exceptions for errors.
 * Test class - EinsteinAuthServiceTest
 * Author - Reetabrata
 */

public class EinsteinAuthService {

    /**
     * Inner class to deserialize the JSON token response from the OAuth server.
     */
    public class TokenResponse {
        public String access_token;
        public String instance_url;
        public String token_type;
        public Integer expires_in;
    }
    
    /**
     * @description
     * Retrieves an OAuth 2.0 access token using client credentials.
     *
     * @return access_token as a String for authorization in subsequent API calls.
     * @throws CustomAuthException if configuration is missing/incomplete or the token call fails.
     */
    public static String getAccessToken() {
        // Retrieve and validate configuration
        Custom_Agent_Configuration__mdt config = getConfiguration();
        validateConfiguration(config);

        // Prepare HTTP POST request to get access token
        HttpRequest req = new HttpRequest();
        req.setEndpoint(config.Domain_URL__c + '/services/oauth2/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        // Prepare request body with client credentials
        String body = 'grant_type=client_credentials'
                    + '&client_id=' + EncodingUtil.urlEncode(config.Consumer_Key__c, 'UTF-8')
                    + '&client_secret=' + EncodingUtil.urlEncode(config.Consumer_Secret__c, 'UTF-8');
        req.setBody(body);

        // Send request and parse response
        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            // Parse JSON response and return access token
            TokenResponse token = (TokenResponse) JSON.deserialize(res.getBody(), TokenResponse.class);
            return token.access_token;
        } else {
            // Log error and throw custom exception
            System.debug(LoggingLevel.ERROR, 'Token request failed: ' + res.getBody());
            throw new CustomAuthException('Failed to retrieve token. Status: ' + res.getStatus());
        }
    }
    
    /**
     * @description
     * Retrieves the first available configuration record from Custom Metadata.
     *
     * @return Custom_Agent_Configuration__mdt instance.
     * @throws CustomAuthException if no configuration is found.
     */
    @TestVisible
    public static Custom_Agent_Configuration__mdt getConfiguration() {
        List<Custom_Agent_Configuration__mdt> configs = [
            SELECT Consumer_Key__c, Consumer_Secret__c, Domain_URL__c
            FROM Custom_Agent_Configuration__mdt
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            throw new CustomAuthException('Custom Agent Configuration not found.');
        }

        return configs[0];
    }
    
    /**
     * @description
     * Validates required fields in the configuration record.
     *
     * @param config The metadata record to validate.
     * @throws CustomAuthException if any required field is missing.
     */
    @TestVisible
    private static void validateConfiguration(Custom_Agent_Configuration__mdt config) {
        if (String.isBlank(config.Consumer_Key__c) ||
            String.isBlank(config.Consumer_Secret__c) ||
            String.isBlank(config.Domain_URL__c)) {
            throw new CustomAuthException('Incomplete configuration in Custom Metadata.');
        }
    }
    
    /**
     * @description
     * Custom exception for token handling and configuration issues.
     */
    public class CustomAuthException extends Exception {}
}