public class PunchOutHandler {

    public static void calculateDistance(List<User_Punch_State__c> outRecords) {
        if (outRecords == null || outRecords.isEmpty()) {
            return;
        }

        // 1. Take each User_Punch_State__c record's owner
        Set<Id> ownerIds = new Set<Id>();
        for (User_Punch_State__c state : outRecords) {
            if (state.OwnerId != null) {
                ownerIds.add(state.OwnerId);
            }
        }

        if (ownerIds.isEmpty()) {
            return;
        }

        // Collect the rate from metadata
        Map<String, Decimal> rateMap = new Map<String, Decimal>();
        for (Employee_Level_Rate_KM__mdt mdt : [
                SELECT Employee_Level__c, Vehical_Type__c, Rate_Per_KM__c
                FROM Employee_Level_Rate_KM__mdt]) {
            String key = mdt.Employee_Level__c + '|' + mdt.Vehical_Type__c;
            rateMap.put(key, mdt.Rate_Per_KM__c);
        }

        // Query Users with Employee Level
        Map<Id, User> userMap = new Map<Id, User>(
            [SELECT Id, Employee_Level__c FROM User WHERE Id IN :ownerIds]
        );

        // 2. Query Punch_Record__c for that day for each owner
        List<Punch_Record__c> punchRecords = [
            SELECT Id, OwnerId, User__c, Punch_Type__c, Action__c, Is_Expense_Created__c,
                   Vehicle_Type__c, Odometer_Reading__c, Extracted_Odometer_Reading__c,
                   Punch_Time__c, CreatedDate,
                   Punch_Out_Of__c,
                   Punch_Out_Of__r.Odometer_Reading__c,
                   Punch_Out_Of__r.Extracted_Odometer_Reading__c,
                   Punch_Out_Of__r.Punch_Time__c,
                   Punch_Out_Of__r.CreatedDate
            FROM Punch_Record__c
            WHERE (OwnerId IN :ownerIds OR User__c IN :ownerIds)
              AND CreatedDate = TODAY
              AND Punch_Type__c = 'Market Visit'
              AND Action__c = 'OUT'
              AND Is_Expense_Created__c = false
              AND Vehicle_Type__c IN ('Two Wheeler', 'Four Wheeler')
            ORDER BY CreatedDate ASC
        ];

        if (punchRecords.isEmpty()) {
            return;
        }

        // Group punch records by Owner
        Map<Id, List<Punch_Record__c>> ownerToPunches = new Map<Id, List<Punch_Record__c>>();
        for (Punch_Record__c pr : punchRecords) {
            Id ownerKey = pr.OwnerId != null ? pr.OwnerId : pr.User__c;
            if (!ownerToPunches.containsKey(ownerKey)) {
                ownerToPunches.put(ownerKey, new List<Punch_Record__c>());
            }
            ownerToPunches.get(ownerKey).add(pr);
        }

        List<Expense__c> expensesToInsert = new List<Expense__c>();
        List<List<LineWrapper>> linesPerExpense = new List<List<LineWrapper>>();
        List<Punch_Record__c> punchesToUpdate = new List<Punch_Record__c>();

        for (Id ownerId : ownerToPunches.keySet()) {
            User usr = userMap.get(ownerId);
            String employeeLevel = (usr != null && usr.Employee_Level__c != null)
                ? usr.Employee_Level__c.trim()
                : '';

            if (String.isEmpty(employeeLevel)) {
                continue;
            }

            List<Punch_Record__c> userPunches = ownerToPunches.get(ownerId);
            List<LineWrapper> expenseLines = new List<LineWrapper>();
            Date earliestStartDate = null;

            for (Punch_Record__c pr : userPunches) {
                Punch_Record__c inRecord = pr.Punch_Out_Of__r;

                // 4. AI_Extracted_Distance__c = Punch_Record__c.Extracted_Odometer_Reading__c - Punch_Out_Of__c.Extracted_Odometer_Reading__c
                Decimal aiDistance = null;
                if (pr.Extracted_Odometer_Reading__c != null && inRecord != null && inRecord.Extracted_Odometer_Reading__c != null) {
                    aiDistance = pr.Extracted_Odometer_Reading__c - inRecord.Extracted_Odometer_Reading__c;
                }

                // 5. Manually_Extracted_Distance__c = Punch_Record__c.Odometer_Reading__c - Punch_Out_Of__c.Odometer_Reading__c
                Decimal manualDistance = null;
                if (pr.Odometer_Reading__c != null && inRecord != null && inRecord.Odometer_Reading__c != null) {
                    manualDistance = pr.Odometer_Reading__c - inRecord.Odometer_Reading__c;
                }

                Decimal effectiveDistance = (aiDistance != null) ? aiDistance : (manualDistance != null ? manualDistance : 0);
                String mappedVehicle = mapVehicleTypePicklist(pr.Vehicle_Type__c);
                String rateKey = employeeLevel + '|' + mappedVehicle;
                Decimal ratePerKm = rateMap.containsKey(rateKey)
                    ? rateMap.get(rateKey)
                    : (rateMap.containsKey(employeeLevel + '|' + pr.Vehicle_Type__c) ? rateMap.get(employeeLevel + '|' + pr.Vehicle_Type__c) : 0);
                Decimal amount = effectiveDistance * ratePerKm;

                Date punchInDate = (inRecord != null && inRecord.CreatedDate != null)
                    ? inRecord.CreatedDate.date()
                    : (pr.CreatedDate != null ? pr.CreatedDate.date() : Date.today());

                Date punchOutDate = (pr.CreatedDate != null)
                    ? pr.CreatedDate.date()
                    : Date.today();

                if (earliestStartDate == null || punchInDate < earliestStartDate) {
                    earliestStartDate = punchInDate;
                }

                LineWrapper lw = new LineWrapper();
                lw.punchRecordId   = pr.Id;
                lw.mappedVehicle   = mappedVehicle;
                lw.vehicleType     = pr.Vehicle_Type__c;
                lw.aiDistance      = aiDistance;
                lw.manualDistance  = manualDistance;
                lw.dispDistance    = (aiDistance != null) ? aiDistance : manualDistance;
                lw.amount          = amount;
                lw.ratePerKm       = ratePerKm;
                lw.lineDate        = punchOutDate;
                expenseLines.add(lw);

                // Mark Is_Expense_Created__c of Punch_Record__c to true
                punchesToUpdate.add(new Punch_Record__c(
                    Id = pr.Id,
                    Is_Expense_Created__c = true
                ));
            }

            if (!expenseLines.isEmpty()) {
                Expense__c exp = new Expense__c(
                    Employee__c                   = ownerId,
                    Employee_Level__c             = employeeLevel,
                    Status__c                     = 'New',
                    Purpose__c                    = 'Market Visit - Own vehicle travel reimbursement',
                    Travel_Start_Date__c          = earliestStartDate != null ? earliestStartDate : Date.today(),
                    Is_Private_Vehicle_Expense__c = true,
                    Submitted_Date__c             = System.now().date()
                );
                expensesToInsert.add(exp);
                linesPerExpense.add(expenseLines);
            }
        }

        // 3. Create Expense__c and Expense_Line__c records
        if (!expensesToInsert.isEmpty()) {
            insert expensesToInsert;

            List<Expense_Line__c> linesToInsert = new List<Expense_Line__c>();
            for (Integer i = 0; i < expensesToInsert.size(); i++) {
                Expense__c exp = expensesToInsert[i];
                List<LineWrapper> lines = linesPerExpense[i];
                for (LineWrapper lw : lines) {
                    linesToInsert.add(new Expense_Line__c(
                        Expense__c                     = exp.Id,
                        Punch_Record__c                = lw.punchRecordId,
                        Expense_Type__c                = 'Own Vehicle',
                        Vehicle_Type__c                = lw.mappedVehicle,
                        AI_Extracted_Distance__c       = lw.aiDistance,
                        Manually_Extracted_Distance__c = lw.manualDistance,
                        Is_Private_Vehicle_Expense__c  = true,
                        Amount__c                      = lw.amount,
                        Date__c                        = lw.lineDate,
                        Description__c                 = 'Distance ' + lw.dispDistance + ' KM x Rs.'
                                                       + lw.ratePerKm + '/KM (' + lw.vehicleType + ')',
                        Bill_Attached__c               = false
                    ));
                }
            }

            if (!linesToInsert.isEmpty()) {
                insert linesToInsert;
            }

            // 6. After successful creation of expense mark Is_Expense_Created__c to true
            if (!punchesToUpdate.isEmpty()) {
                update punchesToUpdate;
            }
        }
    }

    // ─── Match the vehicle value ───────────────────────────────────
    private static String mapVehicleTypePicklist(String vehicleType) {
        if (String.isBlank(vehicleType)) return null;
        String v = vehicleType.toLowerCase().trim();
        if (v.contains('four') || v.contains('4')) return '4-Wheeler';
        if (v.contains('two')  || v.contains('2')) return '2-Wheeler';
        return null;
    }

    private class LineWrapper {
        Id      punchRecordId;
        String  mappedVehicle;
        String  vehicleType;
        Decimal aiDistance;
        Decimal manualDistance;
        Decimal dispDistance;
        Decimal amount;
        Decimal ratePerKm;
        Date    lineDate;
    }

}