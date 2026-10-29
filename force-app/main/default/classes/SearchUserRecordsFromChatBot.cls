public without sharing class SearchUserRecordsFromChatBot {

    /*
     * Wrapper class for Agent Action Input
     */
    public class ChatBotInput {

        @InvocableVariable(
            required=true
            label='JSON Payload'
            description='JSON payload received from Agentforce'
        )
        public String jsonInput;

        @InvocableVariable(
            required=false
            label='Logged In Username'
            description='Username of the currently logged-in user'
        )
        public String loggedInUsername;
    }

    /*
     * deserialized from jsonInput
     */
    public class SearchRequest {

        public String objectType;
        public String email;
        public String phone;
        public String loggedInUsername;

    }

    /*
     * Individual matching record 
     */
    public class SearchResult {

        public String recordId;
        public String recordName;
        public String objectType;

    }

    /*
     * Wrapper class for Agent Action Output.
     * Returning a real typed collection (instead of a JSON string) lets
     * Agentforce auto-render this as a structured list/table.
     */
    public class ChatBotOutput {

        @InvocableVariable(
            label='Matching Records'
            description='List of matching Account, Lead, or Opportunity records'
        )
        public List<SearchResult> records;

        @InvocableVariable(
            label='Record Count'
            description='Number of matching records found'
        )
        public Integer recordCount;
    }

    /*
     * Custom Exception
     */
    public class SearchUserRecordsException extends Exception {}

    @InvocableMethod(
        label='Search User Records'
        description='Returns matching Account, Lead or Opportunity records'
    )
    public static List<ChatBotOutput> searchRecords(List<ChatBotInput> inputs) {

        List<ChatBotOutput> responses = new List<ChatBotOutput>();

        for(ChatBotInput input : inputs){

            ChatBotOutput out = new ChatBotOutput();
            out.records = new List<SearchResult>();
            out.recordCount = 0;

            if(String.isBlank(input.jsonInput)){
                responses.add(out);
                continue;
            }

            try{

                SearchRequest request =
                    (SearchRequest)JSON.deserialize(
                        input.jsonInput,
                        SearchRequest.class
                    );

                request.loggedInUsername = input.loggedInUsername;
                System.debug('RAW input.loggedInUsername: [' + input.loggedInUsername + ']');

                request.objectType = request.objectType != null ? request.objectType.trim() : null;
                request.email = request.email != null ? request.email.trim() : null;
                request.phone = request.phone != null ? request.phone.trim() : null;

                if(String.isBlank(request.objectType)){
                    throw new SearchUserRecordsException('Object Type is required.');
                }

                if(String.isBlank(request.email)){
                    throw new SearchUserRecordsException('Email is required.');
                }

                if(String.isBlank(request.phone)){
                    throw new SearchUserRecordsException('Phone Number is required.');
                }

                Id userId;

                if(String.isNotBlank(request.loggedInUsername)){

                    System.debug('Attempting to resolve userId for username: [' + request.loggedInUsername + ']');

                    List<User> matchingUsers = [
                        SELECT Id
                        FROM User
                        WHERE Username = :request.loggedInUsername
                        AND IsActive = true
                        LIMIT 1
                    ];

                    System.debug('matchingUsers found: ' + matchingUsers.size() + ' -> ' + matchingUsers);

                    if(!matchingUsers.isEmpty()){
                        userId = matchingUsers[0].Id;
                    }
                    else{
                        System.debug('loggedInUsername did not match any active User.');
                    }
                }
                else{
                    System.debug('loggedInUsername was BLANK/NULL — skipping user lookup entirely.');
                }

                System.debug('FINAL resolved userId used in queries: ' + userId);

                List<SearchResult> results = new List<SearchResult>();

                if(request.objectType.equalsIgnoreCase('Account')){

                    results.addAll(
                        searchAccounts(
                            request.email,
                            request.phone,
                            userId
                        )
                    );

                }
                else if(request.objectType.equalsIgnoreCase('Lead')){

                    results.addAll(
                        searchLeads(
                            request.email,
                            request.phone,
                            userId
                        )
                    );

                }
                else if(request.objectType.equalsIgnoreCase('Opportunity')){

                    results.addAll(
                        searchOpportunities(
                            request.email,
                            request.phone,
                            userId
                        )
                    );

                }
                else{

                    throw new SearchUserRecordsException(
                        'Invalid Object Type : ' + request.objectType
                    );

                }

                out.records = results;
                out.recordCount = results.size();
                responses.add(out);

            }
            catch(Exception ex){

                throw new SearchUserRecordsException(
                    'Error while searching records : ' + ex.getMessage()
                );

            }

        }

        return responses;

    }

    /*
     * Search Account
     */
    private static List<SearchResult> searchAccounts(
        String email,
        String phone,
        Id userId
    ){

        List<SearchResult> output = new List<SearchResult>();

        List<Account> accounts = [

            SELECT
                Id,
                Name,
                Email__c,
                Phone

            FROM Account

            WHERE
                CreatedById = :userId
                AND Email__c = :email
                AND Phone = :phone
                WITH SYSTEM_MODE

            ORDER BY Name

        ];

        for(Account acc : accounts){

            SearchResult row = new SearchResult();

            row.recordId = acc.Id;
            row.recordName = acc.Name;
            row.objectType = 'Account';

            output.add(row);

        }

        return output;

    }

    /*
     * Search Lead
     */
    private static List<SearchResult> searchLeads(
        String email,
        String phone,
        Id userId
    ){

        List<SearchResult> output = new List<SearchResult>();

        List<Lead> leads = [

            SELECT
                Id,
                Name,
                Company,
                Email,
                Phone

            FROM Lead

            WHERE
                CreatedById = :userId
                AND Email = :email
                AND Phone = :phone
                WITH SYSTEM_MODE

            ORDER BY Name

        ];

        for(Lead lead : leads){

            SearchResult row = new SearchResult();

            row.recordId = lead.Id;
            row.recordName = lead.Name;
            row.objectType = 'Lead';

            output.add(row);

        }

        return output;

    }

    /*
     * Search Opportunity
     */
    private static List<SearchResult> searchOpportunities(
        String email,
        String phone,
        Id userId
    ){

        List<SearchResult> output = new List<SearchResult>();

        List<Opportunity> opportunities = [

            SELECT
                Id,
                Name,
                StageName,
                Email__c,
                Phone__c

            FROM Opportunity

            WHERE
                CreatedById = :userId
                AND Email__c = :email
                AND Phone__c = :phone
                WITH SYSTEM_MODE

            ORDER BY Name

        ];

        for(Opportunity opp : opportunities){

            SearchResult row = new SearchResult();

            row.recordId = opp.Id;
            row.recordName = opp.Name;
            row.objectType = 'Opportunity';

            output.add(row);

        }

        return output;

    }

}