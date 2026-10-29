global class OpportunityCaptureAction {
    @InvocableMethod(
        label='Create Opportunity'
        description='Creates an Account and Opportunity record from captured fields'
        category='Opportunity Management'
    )
    global static List<String> createOpportunity(
        List<OpportunityInput> inputs
    ) {
        List<String> results = new List<String>();
        for (OpportunityInput inp : inputs) {

            // Auto-create a new Account with Phone & Email
            Account acc = new Account();
            acc.Name  = inp.accountName;
            acc.Phone = inp.accountPhone;
            acc.Email__c =inp.accountEmail;
            insert acc;

            // Create Opportunity linked to new Account
            Opportunity o = new Opportunity();
            o.Name      = inp.opportunityName;
            o.CloseDate = Date.valueOf(inp.closeDate);
            o.StageName = inp.stageName;
            o.AccountId = acc.Id;
            o.OwnerId   = inp.ownerId != null && inp.ownerId != ''
                              ? inp.ownerId
                              : UserInfo.getUserId();
            insert o;

            results.add(
                'Account created: ' + acc.Id +
                ' | Opportunity created: ' + o.Id
            );
        }
        return results;
    }

    global class OpportunityInput {
        @InvocableVariable(
            label='Opportunity Name' required=true)
        global String opportunityName;

        @InvocableVariable(
            label='Close Date' required=true)
        global String closeDate; // YYYY-MM-DD

        @InvocableVariable(
            label='Stage Name' required=true)
        global String stageName;

        @InvocableVariable(
            label='Account Name' required=true)
        global String accountName;

        @InvocableVariable(
            label='Account Phone' required=true)
        global String accountPhone;

        @InvocableVariable(
            label='Account Email' required=true)
        global String accountEmail;

        @InvocableVariable(
            label='Owner Id' required=false)
        global String ownerId;
    }
}