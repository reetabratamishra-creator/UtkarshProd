global class RecordCountAction {
    @InvocableMethod(
        label='Get Record Counts'
        description='Returns count of Leads and Opportunities in Salesforce'
        category='Reports'
    )
    global static List<String> getRecordCounts(
        List<RecordCountInput> inputs
    ) {
        List<String> results = new List<String>();
        for (RecordCountInput inp : inputs) {
            
            Integer leadCount = 0;
            Integer oppCount  = 0;
            Integer accCount  = 0;

            if (inp.objectName == 'Lead' || inp.objectName == 'All') {
                leadCount = [SELECT COUNT() FROM Lead];
            }
            if (inp.objectName == 'Opportunity' || inp.objectName == 'All') {
                oppCount = [SELECT COUNT() FROM Opportunity];
            }
            if (inp.objectName == 'Account' || inp.objectName == 'All') {
                accCount = [SELECT COUNT() FROM Account];
            }

            String result = '';
            if (inp.objectName == 'All') {
                result = 'Total Leads: ' + leadCount + 
                         ' | Total Opportunities: ' + oppCount + 
                         ' | Total Accounts: ' + accCount;
            } else if (inp.objectName == 'Lead') {
                result = 'Total Leads: ' + leadCount;
            } else if (inp.objectName == 'Opportunity') {
                result = 'Total Opportunities: ' + oppCount;
            } else if (inp.objectName == 'Account') {
                result = 'Total Accounts: ' + accCount;
            }

            results.add(result);
        }
        return results;
    }

    global class RecordCountInput {
        @InvocableVariable(
            label='Object Name' required=true)
        global String objectName; // Lead, Opportunity, Account, All
    }
}