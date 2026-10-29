global class LeadCaptureAction {
    @InvocableMethod(
        label='Create Lead'
        description='Creates a Lead record from captured fields'
        category='Lead Management'
    )
    global static List<String> createLead(
        List<LeadInput> inputs
    ) {
        List<String> results = new List<String>();
        for (LeadInput inp : inputs) {
            Lead l = new Lead();
            l.FirstName  = inp.firstName;
            l.LastName   = inp.lastName;
            l.Company    = inp.company;
            l.Phone      = inp.phone;
            l.Email      = inp.email;
            l.LeadSource = 'Agentforce';

            // Use passed-in userId if provided, else fall back to running user
            if (inp.ownerId != null && inp.ownerId != '') {
                l.OwnerId = inp.ownerId;
            } else {
                l.OwnerId = UserInfo.getUserId();
            }

            insert l;
            results.add('Lead created: ' + l.Id);
        }
        return results;
    }

    global class LeadInput {
        @InvocableVariable(label='First Name' required=true)
        global String firstName;

        @InvocableVariable(label='Last Name' required=true)
        global String lastName;

        @InvocableVariable(label='Company' required=true)
        global String company;

        @InvocableVariable(label='Phone' required=true)
        global String phone;

        @InvocableVariable(label='Email' required=false)
        global String email;

        @InvocableVariable(label='Owner Id' required=false)
        global String ownerId;  
    }
}