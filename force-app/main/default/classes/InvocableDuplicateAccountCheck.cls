public with sharing class InvocableDuplicateAccountCheck {

    public class Request {
        // Enquirer Details===============
        @InvocableVariable
        public String enquirerCompanyName ;
        @InvocableVariable
        public String enquirerPhone;
        @InvocableVariable
        public String enquirerEmail;
    }

    @InvocableMethod(label='Get Duplicate contacts V1' description='Get Duplicate contacts V1')
    public static List<InvokeAccountResponse> InvocableDuplicateAccountCheck(List<Request> requests) {

        Request request = requests[0];
        Boolean duplicateEnquirer;
        String errorMessage;
        List<Account> existingEnquirerAccountList = new List<Account>();
        List<InvokeAccountResponse> result = new List<InvokeAccountResponse>();
        
        Account createNewEnquirerAccount = new Account();
        createNewEnquirerAccount.Name = request.enquirerCompanyName;
        createNewEnquirerAccount.Phone = request.enquirerPhone;
        createNewEnquirerAccount.Email__c = request.enquirerEmail;
       
        List<Account> duplicateEnquirerList = findDuplicateRecords(createNewEnquirerAccount);
        if(!duplicateEnquirerList.isEmpty())
        {
            existingEnquirerAccountList.addAll(duplicateEnquirerList);
            duplicateEnquirer = true;
        }
        else
        {
            duplicateEnquirer = false;
        }
        

        InvokeAccountResponse response = new InvokeAccountResponse();
        response.duplicateAccountEnquirers =existingEnquirerAccountList;
        response.foundDuplicateEnquirers = duplicateEnquirer;
        result.add(response);
        return result;
    }

    public class  InvokeAccountResponse {
        @InvocableVariable
        public List<Account> duplicateAccountEnquirers;
        @InvocableVariable
        public Boolean foundDuplicateEnquirers;  
    }

    // Method for checking Duplicate
/*public static List<SObject> findDuplicateRecords(Account newAccount){
    List<Account> accountList = new List<Account>();
    accountList.add(newAccount);
    
    System.debug('--- Checking duplicates for: Name=' + newAccount.Name 
                  + ', Phone=' + newAccount.Phone 
                  + ', Email=' + newAccount.Email__c);

    List<Datacloud.FindDuplicatesResult> findDuplicatesResult = Datacloud.FindDuplicates.findDuplicates(accountList);
    
    System.debug('Number of FindDuplicatesResult returned: ' + findDuplicatesResult.size());
    
    Datacloud.FindDuplicatesResult fdResult = findDuplicatesResult.get(0);
    List<Datacloud.DuplicateResult> duplicateResults = fdResult.getDuplicateResults();
    
    System.debug('Number of DuplicateResult (i.e. number of Duplicate Rules fired): ' + duplicateResults.size());
    
    List<SObject> duplicates = new List<SObject>();

    for (Datacloud.DuplicateResult duplicateResult : duplicateResults) {
        System.debug('>> Duplicate Rule Name: ' + duplicateResult.getDuplicateRule());
        System.debug('>> Is Allow Save: ' + duplicateResult.isAllowSave());
        
        List<Datacloud.MatchResult> matchResults = duplicateResult.getMatchResults();
        System.debug('   Number of MatchResults (i.e. Matching Rules fired) under this Duplicate Rule: ' + matchResults.size());
        
        for (Datacloud.MatchResult matchResult : matchResults) {
            System.debug('   >> Matching Rule Name: ' + matchResult.getRule());
            System.debug('   >> Match Engine: ' + matchResult.getMatchEngine());
            
            List<Datacloud.MatchRecord> matchRecords = matchResult.getMatchRecords();
            System.debug('      Number of MatchRecords (actual duplicate candidates found): ' + matchRecords.size());
            
            for (Datacloud.MatchRecord matchRecord : matchRecords) {
                Account duplicate = (Account) matchRecord.getRecord();
                
                // Manual comparison - tells us exactly which field(s) actually matched
                Boolean phoneMatches = (newAccount.Phone != null 
                                         && newAccount.Phone == duplicate.Phone);
                Boolean emailMatches = (newAccount.Email__c != null 
                                         && newAccount.Email__c == duplicate.Email__c);
                Boolean nameLooksClose = (newAccount.Name != null 
                                          && duplicate.Name != null 
                                          && newAccount.Name.toLowerCase().contains(duplicate.Name.toLowerCase().left(4)));
                
                System.debug('      -----------------------------------');
                System.debug('      Matched Record Id: ' + duplicate.Id);
                System.debug('      Matched Record Name: ' + duplicate.Name);
                System.debug('      Matched Record Phone: ' + duplicate.Phone);
                System.debug('      Matched Record Email__c: ' + duplicate.Email__c);
                System.debug('      Match Confidence: ' + matchRecord.getMatchConfidence());
                System.debug('      >> Phone exact match?  ' + phoneMatches);
                System.debug('      >> Email exact match?  ' + emailMatches);
                System.debug('      >> Name loosely similar? ' + nameLooksClose);
                
                duplicates.add(duplicate);
            }
        }
    }
    
    System.debug('Total duplicates found: ' + duplicates.size());
    return duplicates;
}*/
public static List<SObject> findDuplicateRecords(Account newAccount){
    List<Account> accountList = new List<Account>();
    accountList.add(newAccount);

    System.debug('=== INPUT ACCOUNT ===');
    System.debug('Name=' + newAccount.Name + ', Phone=' + newAccount.Phone + ', Email=' + newAccount.Email__c);

    List<Datacloud.FindDuplicatesResult> findDuplicatesResult = Datacloud.FindDuplicates.findDuplicates(accountList);
    Datacloud.FindDuplicatesResult fdResult = findDuplicatesResult.get(0);
    List<Datacloud.DuplicateResult> duplicateResults = fdResult.getDuplicateResults();

    // Step 1: collect only the Ids from the match engine.
    Set<Id> candidateIds = new Set<Id>();
    for (Datacloud.DuplicateResult duplicateResult : duplicateResults) {
        for (Datacloud.MatchResult matchResult : duplicateResult.getMatchResults()) {
            for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                candidateIds.add(matchRecord.getRecord().Id);
            }
        }
    }
    System.debug('Total raw candidate Ids from match engine: ' + candidateIds.size());

    if (candidateIds.isEmpty()) {
        return new List<SObject>();
    }

    // Step 2: re-query those Ids ourselves so every field we need is safely loaded
    Map<Id, Account> candidateAccounts = new Map<Id, Account>(
        [SELECT Id, Name, Phone, Email__c FROM Account WHERE Id IN :candidateIds]
    );

    // Step 3: compare and clearly label WHICH check matched
    List<Id> phoneMatchedIds = new List<Id>();
    List<Id> emailMatchedIds = new List<Id>();
    List<Id> nameMatchedIds  = new List<Id>();
    List<SObject> duplicates = new List<SObject>();

    for (Account duplicate : candidateAccounts.values()) {
        Boolean phoneMatches = (newAccount.Phone != null && newAccount.Phone == duplicate.Phone);
        Boolean emailMatches = (newAccount.Email__c != null && newAccount.Email__c == duplicate.Email__c);
        Boolean nameLooksClose = (newAccount.Name != null && duplicate.Name != null
                && newAccount.Name.toLowerCase().contains(duplicate.Name.toLowerCase().left(4)));

        List<String> matchedOn = new List<String>();
        if (phoneMatches) { matchedOn.add('PHONE'); phoneMatchedIds.add(duplicate.Id); }
        if (emailMatches) { matchedOn.add('EMAIL'); emailMatchedIds.add(duplicate.Id); }
        if (nameLooksClose) { matchedOn.add('FUZZY_NAME'); nameMatchedIds.add(duplicate.Id); }

        if (!matchedOn.isEmpty()) {
            System.debug('DUPLICATE FOUND -> Id: ' + duplicate.Id
                    + ' | Name: ' + duplicate.Name
                    + ' | Phone: ' + duplicate.Phone
                    + ' | Email: ' + duplicate.Email__c
                    + ' | Matched On: ' + String.join(matchedOn, ', '));
            duplicates.add(duplicate);
        } else {
            System.debug('IGNORED (not a real match) -> Id: ' + duplicate.Id + ' | Name: ' + duplicate.Name);
        }
    }

    // Step 4: clean summary at the end
    System.debug('=== SUMMARY ===');
    System.debug('Matched by PHONE (' + phoneMatchedIds.size() + '): ' + phoneMatchedIds);
    System.debug('Matched by EMAIL (' + emailMatchedIds.size() + '): ' + emailMatchedIds);
    System.debug('Matched by FUZZY NAME (' + nameMatchedIds.size() + '): ' + nameMatchedIds);
    System.debug('Total confirmed duplicates: ' + duplicates.size());

    return duplicates;
}
}