public with sharing class CaseSLADueDateCalculator {

    public class Request {

        @InvocableVariable(required=true)
        public String priority;

        @InvocableVariable(required=true)
        public Datetime caseCreatedDate;
    }

    public class Response {

        @InvocableVariable
        public Datetime dueDate;
    }

    @InvocableMethod(label='Calculate SLA Due Date')
    public static List<Response> calculateDueDate(List<Request> requests) {

        List<Response> responses = new List<Response>();

        BusinessHours bh = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];

        for(Request req : requests) {

            Integer slaDays;

            switch on req.priority {
                when 'Critical' {
                    slaDays = 1;
                }
                when 'High' {
                    slaDays = 2;
                }
                when 'Medium' {
                    slaDays = 3;
                }
                when 'Low' {
                    slaDays = 4;
                }
                when else {
                    slaDays = 1;
                }
            }

            Date workingDate = req.caseCreatedDate.date();
            Integer businessDaysAdded = 0;

            while(businessDaysAdded < slaDays) {

                workingDate = workingDate.addDays(1);

                Datetime businessCheckTime = Datetime.newInstance(
                    workingDate.year(),
                    workingDate.month(),
                    workingDate.day(),
                    10,
                    0,
                    0
                );

                if(BusinessHours.isWithin(bh.Id, businessCheckTime)) {
                    businessDaysAdded++;
                }
            }

            Datetime dueDateTime = Datetime.newInstance(
                workingDate.year(),
                workingDate.month(),
                workingDate.day(),
                19, // 7:00 PM
                0,
                0
            );

            Response res = new Response();
            res.dueDate = dueDateTime;
            responses.add(res);
        }

        return responses;
    }
}