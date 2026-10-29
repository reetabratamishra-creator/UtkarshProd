public without sharing class CaseSLADueDateHandler {

    public static void setDueDate(List<Case> newCases, Map<Id, Case> oldCasesById) {
        BusinessHours bh = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];

        for (Case c : newCases) {
            Case previous = (oldCasesById == null) ? null : oldCasesById.get(c.Id);
            Boolean isNewRecord = (previous == null);
            Boolean priorityChanged = (!isNewRecord) && (c.Priority != previous.Priority);

            if (!isNewRecord && !priorityChanged) {
                continue;
            }

            Integer slaDays;
            switch on c.Priority {
                when 'Critical' { slaDays = 1; }
                when 'High'     { slaDays = 2; }
                when 'Medium'   { slaDays = 3; }
                when 'Low'      { slaDays = 4; }
                when else       { slaDays = 1; }
            }

            Date workingDate = isNewRecord ? Date.today() : c.CreatedDate.date();
            Integer businessDaysAdded = 0;

            while (businessDaysAdded < slaDays) {
                workingDate = workingDate.addDays(1);
                Datetime checkTime = Datetime.newInstance(
                    workingDate.year(), workingDate.month(), workingDate.day(), 10, 0, 0
                );
                if (BusinessHours.isWithin(bh.Id, checkTime)) {
                    businessDaysAdded++;
                }
            }

            c.Due_Date_Time__c = Datetime.newInstance(
                workingDate.year(), workingDate.month(), workingDate.day(), 19, 0, 0
            );
        }
    }
}