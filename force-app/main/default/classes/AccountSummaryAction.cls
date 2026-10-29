public with sharing class AccountSummaryAction {

    public class Request {
        @InvocableVariable(required=true label='Account Id')
        public Id accountId;
    }

    public class Result {
        @InvocableVariable public String accountName;
        @InvocableVariable public String industry;
        @InvocableVariable public String accountOwner;
        @InvocableVariable public Decimal annualRevenue;
        @InvocableVariable public String billingCity;
        @InvocableVariable public String phone;
        @InvocableVariable public String website;

        @InvocableVariable(description='Ready-to-read summary of the account')
        public String summaryText;
    }

    @InvocableMethod(label='Get Account Summary' description='Summarizes basic Account details')
    public static List<Result> getAccountSummary(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Account acc = [
                SELECT Id, Name, Industry, AnnualRevenue, BillingCity, Phone, Website, Owner.Name
                FROM Account
                WHERE Id = :req.accountId
                LIMIT 1
            ];

            Result r = new Result();
            r.accountName = acc.Name;
            r.industry = acc.Industry;
            r.accountOwner = acc.Owner?.Name;
            r.annualRevenue = acc.AnnualRevenue;
            r.billingCity = acc.BillingCity;
            r.phone = acc.Phone;
            r.website = acc.Website;

            r.summaryText = acc.Name +
                (acc.Industry != null ? ' is in the ' + acc.Industry + ' industry' : '') +
                (acc.BillingCity != null ? ', based in ' + acc.BillingCity : '') +
                (acc.AnnualRevenue != null ? ', with annual revenue of approximately $' + acc.AnnualRevenue.setScale(0) : '') +
                '. Account owner: ' + (acc.Owner != null ? acc.Owner.Name : 'Unassigned') + '.';

            results.add(r);
        }
        return results;
    }
}