public class EmployeeTimelineController {

    // ---------------- DTOs ----------------

    public class TimelineItemDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String description;
        @AuraEnabled public Datetime createdTime;
        @AuraEnabled public String createdByName;
        @AuraEnabled public String clientName;
        @AuraEnabled public Boolean isCheckout;
        @AuraEnabled public String visitType;
        @AuraEnabled public String customerType;
        @AuraEnabled public String customerCategory;
        @AuraEnabled public Datetime loggedAt;
        @AuraEnabled public Datetime loggedOutAt;
        @AuraEnabled public String mom;
        @AuraEnabled public String visitOutcome;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String followUpDate;
        @AuraEnabled public String justification;
        @AuraEnabled public Boolean is100mOutside;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String nodeDistance;
        @AuraEnabled public List<Map<String, String>> files;
    }

    public class ClientOptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal distanceKm;
    }

    public class TaskLogDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String nextAction;
        @AuraEnabled public String reasonForVisit;
        @AuraEnabled public String visitType;
        @AuraEnabled public Date followUpDate;
        @AuraEnabled public String description;
        @AuraEnabled public String clientName;
        @AuraEnabled public String customerType;
        // Which record the visit is anchored to: Lead / Opportunity / Account.
        // Distinct from customerType, which is the New/Existing picklist.
        @AuraEnabled public String associationType;
        @AuraEnabled public Id leadId;
        @AuraEnabled public String leadName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Boolean isCancelled;
        @AuraEnabled public String cancelReason;
    }

    // ---------------- TIMELINE: GET ----------------

    @AuraEnabled(cacheable=true)
    public static List<TimelineItemDTO> getEmployeeTimeline(Id employeeId, Integer limitSize) {
        system.System.debug('employeeId : '+employeeId);
        if (employeeId == null) {
            return new List<TimelineItemDTO>();
        }
        if (limitSize == null || limitSize <= 0) {
            limitSize = 100;
        }

        // Visits belong to the open Day In session, not calendar-today.
        // If Day In started two days ago and Day Out has not happened, the board
        // must still show those check-in/out cards (and new visits linked to that session).
        String idPrefix = String.valueOf(employeeId).substring(0, 3);
        String employeeIdPrefix = System.Label.Employee_Id;
        Boolean isUserId = (idPrefix == employeeIdPrefix);
        Datetime sessionStart = resolveTimelineWindowStart(employeeId, isUserId);
        Datetime sessionEnd = Datetime.newInstance(Date.today().addDays(1), Time.newInstance(0, 0, 0, 0));

        List<Punch_Record__c> punches;
        if (isUserId) { // User ID prefix
            punches = [SELECT Id FROM Punch_Record__c WHERE User__c = :employeeId AND Is_WFH_Request__c != true AND Is_WFO_Request__c != true AND Punch_Time__c >= :sessionStart AND Punch_Time__c < :sessionEnd];
        } else {
            punches = [SELECT Id FROM Punch_Record__c WHERE Employee__c = :employeeId AND Is_WFH_Request__c != true AND Is_WFO_Request__c != true AND Punch_Time__c >= :sessionStart AND Punch_Time__c < :sessionEnd];
        }

        Set<Id> punchIds = new Set<Id>();
        for (Punch_Record__c p : punches) {
            punchIds.add(p.Id);
        }

        // Active mode punch (e.g. Market Visit from a prior calendar day) must be included
        // even if Punch_Time falls outside a fallback "today" window.
        if (isUserId) {
            List<User_Punch_State__c> states = [SELECT Punch_In_Record__c FROM User_Punch_State__c WHERE User__c = :employeeId LIMIT 1];
            if (!states.isEmpty() && states[0].Punch_In_Record__c != null) {
                punchIds.add(states[0].Punch_In_Record__c);
            }
        }

        if (punchIds.isEmpty()) {
            return new List<TimelineItemDTO>();
        }

        // Task logs under this Day In session's punches (exclude pure schedule templates)
        List<Task_Log__c> logs = [
            SELECT Id, Description__c, Reason_for_Visit__c, CreatedDate, IsCheckout__c, CreatedBy.Name, Client_Deatils__r.Name,
                   Account__r.Name, Lead__c, Lead__r.Name, Lead__r.Customer_Category__c, Opportunity__c, Opportunity__r.Name,
                   Opportunity__r.Customer_Category__c, Visit_Type__c, Customer_Type__c, Logged_At__c, Logged_Out_At__c,
                   MOM__c, Visit_outcome__c, Next_Action__c, Next_Follow_Up_Date__c, Justification__c, is100mOutside__c,
                   Latitude__c, Longitude__c FROM Task_Log__c WHERE Punch_Record__c IN :punchIds AND Is_schedule__c = false
            ORDER BY CreatedDate DESC LIMIT :limitSize
        ];

        // Collect Files/Attachments for timeline entries
        Set<Id> parentIds = new Set<Id>();
        for (Task_Log__c l : logs) {
            parentIds.add(l.Id);
        }

        Map<Id, List<Map<String, String>>> fileMap = new Map<Id, List<Map<String, String>>>();
        if (!parentIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, FirstPublishLocationId, Title, FileExtension, FileType
                FROM ContentVersion
                WHERE FirstPublishLocationId IN :parentIds AND IsLatest = true
            ]) {
                if (!fileMap.containsKey(cv.FirstPublishLocationId)) {
                    fileMap.put(cv.FirstPublishLocationId, new List<Map<String, String>>());
                }
                Map<String, String> fileInfo = new Map<String, String>();
                fileInfo.put('id', cv.Id);
                fileInfo.put('title', cv.Title);
                fileInfo.put('extension', cv.FileExtension);
                fileInfo.put('url', '/sfc/servlet.shepherd/version/download/' + cv.Id);
                
                String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : '';
                Boolean isImg = (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif');
                fileInfo.put('isImage', String.valueOf(isImg));

                fileMap.get(cv.FirstPublishLocationId).add(fileInfo);
            }

            Map<Id, Set<Id>> entityToDocIds = new Map<Id, Set<Id>>();
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId, ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :parentIds
            ]) {
                if (!entityToDocIds.containsKey(cdl.LinkedEntityId)) {
                    entityToDocIds.put(cdl.LinkedEntityId, new Set<Id>());
                }
                entityToDocIds.get(cdl.LinkedEntityId).add(cdl.ContentDocumentId);
            }

            if (!entityToDocIds.isEmpty()) {
                Set<Id> docIds = new Set<Id>();
                for (Set<Id> ids : entityToDocIds.values()) {
                    docIds.addAll(ids);
                }
                Map<Id, ContentVersion> docToVersionMap = new Map<Id, ContentVersion>();
                for (ContentVersion cv : [
                    SELECT ContentDocumentId, Id, Title, FileExtension, FileType
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :docIds AND IsLatest = true
                ]) {
                    docToVersionMap.put(cv.ContentDocumentId, cv);
                }

                for (Id entityId : entityToDocIds.keySet()) {
                    if (!fileMap.containsKey(entityId)) {
                        fileMap.put(entityId, new List<Map<String, String>>());
                    }
                    for (Id dId : entityToDocIds.get(entityId)) {
                        if (docToVersionMap.containsKey(dId)) {
                            ContentVersion cv = docToVersionMap.get(dId);
                            Boolean exists = false;
                            for (Map<String, String> existing : fileMap.get(entityId)) {
                                if (existing.get('id') == cv.Id) {
                                    exists = true;
                                    break;
                                }
                            }
                            if (!exists) {
                                Map<String, String> fileInfo = new Map<String, String>();
                                fileInfo.put('id', cv.Id);
                                fileInfo.put('title', cv.Title);
                                fileInfo.put('extension', cv.FileExtension);
                                fileInfo.put('url', '/sfc/servlet.shepherd/version/download/' + cv.Id);
                                
                                String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : '';
                                Boolean isImg = (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'gif');
                                fileInfo.put('isImage', String.valueOf(isImg));

                                fileMap.get(entityId).add(fileInfo);
                            }
                        }
                    }
                }
            }
        }

        List<TimelineItemDTO> result = new List<TimelineItemDTO>();
        for (Task_Log__c log : logs) {
            TimelineItemDTO dto = new TimelineItemDTO();
            dto.id            = log.Id;
            dto.description   = log.Reason_for_Visit__c;
            dto.createdTime   = log.CreatedDate;
            dto.isCheckout    = log.IsCheckout__c;
            dto.createdByName = log.CreatedBy.Name;
            
            // Resolve clientName — priority: Opportunity > Account > Lead > Client_Details
            if (log.Opportunity__r != null) {
                dto.clientName = log.Opportunity__r.Name;
            } else if (log.Account__r != null) {
                dto.clientName = log.Account__r.Name;
            } else if (log.Lead__r != null) {
                dto.clientName = log.Lead__r.Name;
            } else if (log.Client_Deatils__r != null) {
                dto.clientName = log.Client_Deatils__r.Name;
            } else {
                dto.clientName = 'Unknown Account';
            }

            dto.visitType     = log.Visit_Type__c;
            dto.customerType  = log.Customer_Type__c;
            if (log.Lead__c != null && log.Lead__r != null) {
                dto.customerCategory = log.Lead__r.Customer_Category__c;
            } else if (log.Opportunity__c != null && log.Opportunity__r != null) {
                dto.customerCategory = log.Opportunity__r.Customer_Category__c;
            }
            dto.loggedAt      = log.Logged_At__c != null ? log.Logged_At__c : log.CreatedDate;
            dto.loggedOutAt   = log.Logged_Out_At__c;
            dto.mom           = log.MOM__c;
            dto.visitOutcome  = log.Visit_outcome__c;
            dto.nextAction    = log.Next_Action__c;
            dto.followUpDate  = log.Next_Follow_Up_Date__c != null ? log.Next_Follow_Up_Date__c.format() : '';
            dto.justification = log.Justification__c;
            dto.is100mOutside = log.is100mOutside__c;
            dto.latitude      = log.Latitude__c;
            dto.longitude     = log.Longitude__c;
            dto.files         = fileMap.containsKey(log.Id) ? fileMap.get(log.Id) : new List<Map<String, String>>();
            
            result.add(dto);
        }

        assignActualTravelNodeDistances(result, punchIds);
        return result;
    }

    public static void assignActualTravelNodeDistances(List<TimelineItemDTO> items, Set<Id> punchIds) {
        if (items == null || items.isEmpty()) {
            return;
        }

        List<Track_Location__c> tracks = new List<Track_Location__c>();
        if (punchIds != null && !punchIds.isEmpty()) {
            tracks = [SELECT Latitude__c, Longitude__c, CreatedDate, Recorded_At__c FROM Track_Location__c WHERE Punch_Record__c IN :punchIds ORDER BY Recorded_At__c ASC NULLS LAST, CreatedDate ASC LIMIT 2000];
        }

        List<FieldForceDashboardController.TravelPoint> trackPoints = FieldForceDashboardController.travelPointsFromTracks(tracks);

        List<TimelineItemDTO> chronological = new List<TimelineItemDTO>(items);
        for (Integer i = 0; i < chronological.size(); i++) {
            for (Integer j = i + 1; j < chronological.size(); j++) {
                Datetime ti = chronological[i].loggedAt != null ? chronological[i].loggedAt : chronological[i].createdTime;
                Datetime tj = chronological[j].loggedAt != null ? chronological[j].loggedAt : chronological[j].createdTime;
                if (ti != null && tj != null && ti > tj) {
                    TimelineItemDTO tmp = chronological[i];
                    chronological[i] = chronological[j];
                    chronological[j] = tmp;
                }
            }
        }

        TimelineItemDTO prevItem = null;
        Boolean isFirst = true;
        for (TimelineItemDTO item : chronological) {
            if (isFirst) {
                item.nodeDistance = 'Start';
                isFirst = false;
            } else if (item.latitude != null && item.longitude != null
                    && prevItem != null && prevItem.latitude != null && prevItem.longitude != null) {
                Datetime startTime = prevItem.loggedAt != null ? prevItem.loggedAt : prevItem.createdTime;
                Datetime endTime = item.loggedAt != null ? item.loggedAt : item.createdTime;
                Decimal dist = FieldForceDashboardController.sumActualTravelKm(
                    prevItem.latitude, prevItem.longitude, startTime,
                    item.latitude, item.longitude, endTime,
                    trackPoints
                );
                item.nodeDistance = FieldForceDashboardController.formatNodeKm(dist);
            } else {
                item.nodeDistance = '0 KM';
            }

            if (item.latitude != null && item.longitude != null) {
                prevItem = item;
            }
        }
    }

    /**
     * Start of the punch board window:
     * - Open Day In (no later Day Out): from that Day In time, even if it is a prior calendar day
     * - Day Out happened today: from that session's Day In (overnight shift still visible)
     * - Otherwise: start of today
     */
    public static Datetime resolveTimelineWindowStart(Id recordId, Boolean isUserId) {
        Datetime startOfToday = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));

        List<Punch_Record__c> shiftPunches;
        if (isUserId) {
            shiftPunches = [
                SELECT Id, Action__c, Punch_Time__c FROM Punch_Record__c  WHERE User__c = :recordId
                  AND Is_WFH_Request__c != true AND Is_WFO_Request__c != true AND Punch_Type__c = 'Day In / Out'
                  AND Punch_Time__c != null ORDER BY Punch_Time__c DESC, Id DESC LIMIT 50
            ];
        } else {
            shiftPunches = [
                SELECT Id, Action__c, Punch_Time__c FROM Punch_Record__c WHERE Employee__c = :recordId AND Is_WFH_Request__c != true
                  AND Is_WFO_Request__c != true AND Punch_Type__c = 'Day In / Out' AND Punch_Time__c != null
                ORDER BY Punch_Time__c DESC, Id DESC LIMIT 50
            ];
        }

        Punch_Record__c latestDayIn = null;
        Punch_Record__c latestDayOut = null;
        for (Punch_Record__c punch : shiftPunches) {
            if (latestDayIn == null && punch.Action__c == 'IN') {
                latestDayIn = punch;
            }
            if (latestDayOut == null && punch.Action__c == 'OUT') {
                latestDayOut = punch;
            }
            if (latestDayIn != null && latestDayOut != null) {
                break;
            }
        }

        if (latestDayIn == null) {
            return startOfToday;
        }

        Boolean sessionOpen = latestDayOut == null || latestDayOut.Punch_Time__c < latestDayIn.Punch_Time__c;
        if (sessionOpen || latestDayOut.Punch_Time__c >= startOfToday) {
            return latestDayIn.Punch_Time__c;
        }
        return startOfToday;
    }

    // ---------------- TIMELINE: ADD ----------------

    @AuraEnabled
    public static TimelineItemDTO addEmployeeTimelineItem(
        Id employeeId, String description, Id clientId, Decimal latitude, Decimal longitude, String visitType,
        String customerType, String reasonforVisit, String leadFirstName, String leadLastName, String leadEmail,
        String leadCompanyName, String leadPhone, Boolean isManual, String selfieImageBase64,
        Id leadId, Id accountId, Id opportunityId, Id scheduledVisitId
    ) {
        return addEmployeeTimelineItemWithCategory(
            employeeId, description, clientId, latitude, longitude, visitType, customerType,
            reasonforVisit, leadFirstName, leadLastName, leadEmail, leadCompanyName, leadPhone,
            isManual, selfieImageBase64, leadId, accountId, opportunityId, scheduledVisitId,
            'Market Visit', null, false
        );
    }

    public static TimelineItemDTO addEmployeeTimelineItem(
        Id employeeId,
        String description,
        Id clientId,
        Decimal latitude,
        Decimal longitude,
        String visitType,
        String customerType,
        String reasonforVisit,
        String leadFirstName,
        String leadLastName,
        String leadEmail,
        String leadCompanyName,
        String leadPhone,
        Boolean isManual,
        String selfieImageBase64,
        Id leadId,
        Id accountId,
        Id opportunityId
    ) {
        return addEmployeeTimelineItemWithCategory(
            employeeId, description, clientId, latitude, longitude, visitType, customerType,
            reasonforVisit, leadFirstName, leadLastName, leadEmail, leadCompanyName, leadPhone,
            isManual, selfieImageBase64, leadId, accountId, opportunityId, null,
            'Market Visit', null, false
        );
    }

    @AuraEnabled
    public static TimelineItemDTO addEmployeeTimelineItemWithCategory(
        Id employeeId,
        String description,
        Id clientId,
        Decimal latitude,
        Decimal longitude,
        String visitType,
        String customerType,
        String reasonforVisit,
        String leadFirstName,
        String leadLastName,
        String leadEmail,
        String leadCompanyName,
        String leadPhone,
        Boolean isManual,
        String selfieImageBase64,
        Id leadId,
        Id accountId,
        Id opportunityId,
        Id scheduledVisitId,
        String visitCategory,
        String approvedRequestId,
        Boolean mapAddressToAccount
    ) {
        if (employeeId == null) {
            throw new AuraHandledException('Employee Id is required.');
        }

        // Active Market Visit mode punch (required to add a client visit)
        String idPrefix = String.valueOf(employeeId).substring(0, 3);
        String employeeIdPrefix = System.Label.Employee_Id;
        Id punchId = null;

        if (idPrefix == employeeIdPrefix) {
            List<User_Punch_State__c> states = [
                SELECT Punch_In_Record__c, Punch_In_Record__r.Punch_Type__c, Punch_In_Record__r.Action__c
                FROM User_Punch_State__c
                WHERE User__c = :employeeId
                LIMIT 1
            ];
            if (!states.isEmpty()
                && states[0].Punch_In_Record__c != null
                && states[0].Punch_In_Record__r.Action__c == 'IN'
                && states[0].Punch_In_Record__r.Punch_Type__c == 'Market Visit') {
                punchId = states[0].Punch_In_Record__c;
            }
        }

        if (punchId == null) {
            List<Punch_Record__c> punches;
            if (idPrefix == employeeIdPrefix) {
                punches = [
                    SELECT Id
                    FROM Punch_Record__c
                    WHERE User__c = :employeeId
                      AND Action__c = 'IN'
                      AND Punch_Type__c = 'Market Visit'
                      AND Is_WFH_Request__c != true
                      AND Is_WFO_Request__c != true
                    ORDER BY Punch_Time__c DESC
                    LIMIT 1
                ];
            } else {
                punches = [
                    SELECT Id
                    FROM Punch_Record__c
                    WHERE Employee__c = :employeeId
                      AND Action__c = 'IN'
                      AND Punch_Type__c = 'Market Visit'
                      AND Is_WFH_Request__c != true
                      AND Is_WFO_Request__c != true
                    ORDER BY Punch_Time__c DESC
                    LIMIT 1
                ];
            }
            if (!punches.isEmpty()) {
                // Only allow if this Market Visit IN is still the active punch on state (user path),
                // or for legacy Employee path keep latest Market Visit IN.
                if (idPrefix != employeeIdPrefix) {
                    punchId = punches[0].Id;
                }
            }
        }
        
        if (punchId == null) {
            throw new AuraHandledException('Client visits can only be added while Market Visit mode is active.');
        }

        Task_Log__c log = new Task_Log__c();
        if (idPrefix != employeeIdPrefix) {
            log.Employee__c = employeeId;
        }
        log.Visit_Category__c = visitCategory;
        log.Punch_Record__c   = (String.isNotBlank(approvedRequestId)) ? approvedRequestId : punchId;
        log.Logged_At__c      = System.now();
        log.Reason_for_Visit__c = reasonforVisit;
        log.Visit_Type__c      = visitType;
        log.Customer_Type__c   = getValidCustomerType(customerType);

        Boolean isAccId = false;
        Boolean isOppId = false;
        Boolean isExLeadId = false;
        String logParentId = '';

        // If explicit IDs are provided, prioritize them
        if (leadId != null) {
            log.Lead__c = leadId;
            logParentId = leadId;
            isExLeadId = true;
        }
        if (accountId != null) {
            log.Account__c = accountId;
            logParentId = accountId;
            isAccId = true;
        }
        if (opportunityId != null) {
            log.Opportunity__c = opportunityId;
            try {
                Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
                if (log.Account__c == null && opp.AccountId != null) {
                    log.Account__c = opp.AccountId;
                    logParentId = opp.AccountId;
                    isAccId = true;
                } else if (log.Account__c != null) {
                    logParentId = log.Account__c;
                    isAccId = true;
                } else {
                    logParentId = opportunityId;
                    isOppId = true;
                }
            } catch (Exception e) {
                if (log.Account__c != null) {
                    logParentId = log.Account__c;
                    isAccId = true;
                } else {
                    logParentId = opportunityId;
                    isOppId = true;
                }
            }
        }

        // Fallback to legacy clientId logic if no explicit IDs were provided
        if (leadId == null && accountId == null && opportunityId == null && clientId != null) {
            List<Account> acc = [SELECT Id FROM Account WHERE Id = :clientId LIMIT 1];
            List<Opportunity> opp = [SELECT Id, AccountId FROM Opportunity WHERE Id = :clientId LIMIT 1];
            List<Lead> lead = [SELECT Id FROM Lead WHERE Id = :clientId LIMIT 1];
            if (!acc.isEmpty()) {
                log.Account__c = acc[0].Id;
                logParentId = acc[0].Id;
                isAccId = true;
            }
            if (!opp.isEmpty()) {
                log.Opportunity__c = opp[0].Id;
                if (opp[0].AccountId != null) {
                    log.Account__c = opp[0].AccountId;
                    logParentId = opp[0].AccountId;
                    isAccId = true;
                } else {
                    logParentId = opp[0].Id;
                    isOppId = true;
                }
            }
            if (!lead.isEmpty()) {
                log.Lead__c = lead[0].Id;
                logParentId = lead[0].Id;
                isExLeadId = true;
            }
        }

        if (latitude != null) {
            log.Latitude__c = latitude;
        }
        if (longitude != null) {
            log.Longitude__c = longitude;
        }

        // Address book & Site coordination logic.
        // Callouts must run before any DML in this transaction.
        Account parentCheck = null;
        Boolean isSiteAccount = false;
        Address_Book__c newAddressBook = null;
        Id existingAddressBookId = null;

        if (log.Account__c != null) {
            parentCheck = [
                SELECT Id, ParentId, Location__Latitude__s, Name,
                       BillingStreet, BillingCity, BillingState,
                       BillingPostalCode, BillingCountry, Zone__c,
                       Street__c, City__c, State__c, Country__c, PIN__c
                FROM Account
                WHERE Id = :log.Account__c
                LIMIT 1
            ];
            isSiteAccount = (parentCheck.ParentId != null);

            if (!isSiteAccount) {
                if (clientId != null && clientId.getSObjectType() == Address_Book__c.SObjectType) {
                    existingAddressBookId = clientId;
                } else {
                    MapboxGeocodeService.GeocodeResult geo =
                        MapboxGeocodeService.reverseGeocode(latitude, longitude);
                    newAddressBook = buildAddressBookFromGeocode(
                        log.Account__c,
                        opportunityId != null ? opportunityId : log.Opportunity__c,
                        latitude,
                        longitude,
                        geo,
                        description,
                        parentCheck.Name
                    );
                }
            }
        }

        if (isSiteAccount && parentCheck != null) {
            parentCheck.Location__Latitude__s = latitude;
            parentCheck.Location__Longitude__s = longitude;
            if (String.isNotBlank(description)) {
                parentCheck.Description = description;
            }
            update parentCheck;
        } else if (existingAddressBookId != null) {
            log.Address_Book__c = existingAddressBookId;
            List<Address_Book__c> existingAbs = [
                SELECT Street__c, City__c, State__c, Country__c, PIN__c, Zone__c, Primary_Address__c
                FROM Address_Book__c
                WHERE Id = :existingAddressBookId
                LIMIT 1
            ];
            if (!existingAbs.isEmpty()) {
                if (String.isBlank(log.Address__c)) {
                    log.Address__c = composeAddressBookDisplay(existingAbs[0]);
                }
                if (mapAddressToAccount == true) {
                    stampAccountBillingFromAddressBook(parentCheck, existingAbs[0]);
                }
            }
        } else if (newAddressBook != null) {
            if (mapAddressToAccount == true && parentCheck != null
                    && String.isBlank(parentCheck.Street__c)
                    && String.isBlank(parentCheck.BillingStreet)) {
                newAddressBook.Primary_Address__c = true;
            }
            insert newAddressBook;
            log.Address_Book__c = newAddressBook.Id;
            if (String.isBlank(log.Address__c)) {
                log.Address__c = composeAddressBookDisplay(newAddressBook);
            }
            if (mapAddressToAccount == true) {
                stampAccountBillingFromAddressBook(parentCheck, newAddressBook);
            }
        }

        insert log;

        if (scheduledVisitId != null) {
            List<Task_Log__c> schLogs = [
                SELECT Id, Is_schedule__c, Visit_Status__c
                FROM Task_Log__c
                WHERE Id = :scheduledVisitId
                LIMIT 1
            ];
            if (!schLogs.isEmpty()) {
                schLogs[0].Is_schedule__c = false;
                schLogs[0].Visit_Status__c = 'Completed';
                update schLogs[0];
            }
        }

        // Associate Lead with Account in realtime if required
        if (log.Lead__c != null && log.Account__c != null) {
            Lead ldToUpdate = new Lead(Id = log.Lead__c, Account__c = log.Account__c);
            update ldToUpdate;
        }

        // Keep the Opportunity on the head Account. A Site is a child Account used
        // only to tag the visit; writing it onto Opportunity.AccountId made the
        // next visit treat that Site as the parent and offer another nested Site.
        if (log.Opportunity__c != null && log.Account__c != null) {
            Id headAccountId = resolveHeadAccountId(parentCheck, log.Account__c);
            if (headAccountId != null) {
                Opportunity oppToUpdate = new Opportunity(Id = log.Opportunity__c, AccountId = headAccountId);
                update oppToUpdate;
            }
        }

        // Attach selfie image if provided
        if (String.isNotBlank(selfieImageBase64)) {
            ContentVersion cvSelfie = new ContentVersion();
            String b64 = selfieImageBase64;
            Integer commaIdx = selfieImageBase64.indexOf(',');
            if (commaIdx != -1) {
                b64 = selfieImageBase64.substring(commaIdx + 1);
            }
            cvSelfie.VersionData            = EncodingUtil.base64Decode(b64);
            cvSelfie.Title                  = 'checkin_selfie_' + log.Id + '.jpg';
            cvSelfie.PathOnClient           = 'selfie.jpg';
            cvSelfie.FirstPublishLocationId = log.Id;
            insert cvSelfie;
        }

        TimelineItemDTO dto = new TimelineItemDTO();
        dto.id            = log.Id;
        dto.description   = log.Reason_for_Visit__c;
        dto.createdTime   = System.now();
        dto.createdByName = UserInfo.getName();
        
        System.debug('logParentId === ' + logParentId);
        System.debug('isAccId === ' + isAccId);
        System.debug('isOppId === ' + isOppId);
        System.debug('isExLeadId === ' + isExLeadId);
        if (logParentId != '') {
            if (isAccId) {
                dto.clientName = [SELECT Name FROM Account WHERE Id = :logParentId LIMIT 1].Name;
            } else if (isOppId) {
                dto.clientName = [SELECT Name FROM Opportunity WHERE Id = :logParentId LIMIT 1].Name;
            } else if (isExLeadId) {
                dto.clientName = [SELECT Name FROM Lead WHERE Id = :logParentId LIMIT 1].Name;
            }
        }
        
        return dto;
    }

    // ---------------- NEARBY CLIENTS ----------------
    @AuraEnabled(cacheable=true)
    public static List<ClientOptionDTO> getNearbyClients(Decimal latitude, Decimal longitude, Integer limitSize) {
        if (latitude == null || longitude == null) {
            throw new AuraHandledException('Latitude and longitude are required.');
        }
        if (limitSize == null || limitSize <= 0 || limitSize > 50) {
            limitSize = 10;
        }

        // Change object/fields if your org differs
        // List<Client_Deatils__c> allClients = [
        //     SELECT Id, Name, Latitude__c, Longitude__c
        //     FROM Client_Deatils__c
        //     WHERE Latitude__c != null
        //     AND Longitude__c != null
        //     LIMIT 300
        // ];


        // use account location to find nearby clients
        List<Account> accounts = [
            SELECT Id, Name, Location__Latitude__s, Location__Longitude__s
            FROM Account
            WHERE Location__Latitude__s != null
            AND Location__Longitude__s != null
            LIMIT 100
        ];


        // Build full list with distance
        List<ClientOptionDTO> options = new List<ClientOptionDTO>();


        for (Account c : accounts) {
            if (c.Location__Latitude__s == null || c.Location__Longitude__s == null) {
                continue;
            }

            Decimal distKm = calculateDistanceKm(
                latitude,
                longitude,
                c.Location__Latitude__s,
                c.Location__Longitude__s
            );


            if (distKm == null || distKm > 10) {
                continue;
            }

            ClientOptionDTO dto = new ClientOptionDTO();
            dto.id         = c.Id;
            dto.name       = c.Name;
            dto.distanceKm = distKm;

            options.add(dto);
        }

        // use Opportunity location to find nearby clients
        List<Opportunity> opps = [
            SELECT Id, Name, Location__Latitude__s, Location__Longitude__s
            FROM Opportunity
            WHERE Location__Latitude__s != null
            AND Location__Longitude__s != null
            LIMIT 100
        ];


        for (Opportunity o : opps) {
            if (o.Location__Latitude__s == null || o.Location__Longitude__s == null) {
                continue;
            }

            Decimal distKm = calculateDistanceKm(
                latitude,
                longitude,
                o.Location__Latitude__s,
                o.Location__Longitude__s
            );


            if (distKm == null || distKm > 10) {
                continue;
            }

            ClientOptionDTO dto = new ClientOptionDTO();
            dto.id         = o.Id;
            dto.name       = o.Name;
            dto.distanceKm = distKm;

            options.add(dto);
        }

        // use Lead location to find nearby clients
        List<Lead> leads = [
            SELECT Id, Name, Location__Latitude__s, Location__Longitude__s
            FROM Lead
            WHERE Location__Latitude__s != null
            AND Location__Longitude__s != null
            LIMIT 100
        ];


        for (Lead l : leads) {
            if (l.Location__Latitude__s == null || l.Location__Longitude__s == null) {
                continue;
            }

            Decimal distKm = calculateDistanceKm(
                latitude,
                longitude,
                l.Location__Latitude__s,
                l.Location__Longitude__s
            );


            if (distKm == null || distKm > 10) {
                continue;
            }

            ClientOptionDTO dto = new ClientOptionDTO();
            dto.id         = l.Id;
            dto.name       = l.Name;
            dto.distanceKm = distKm;

            options.add(dto);
        }

        // for (Client_Deatils__c c : allClients) {
        //     if (c.Latitude__c == null || c.Longitude__c == null) {
        //         continue;
        //     }

        //     Decimal distKm = calculateDistanceKm(
        //         latitude,
        //         longitude,
        //         c.Latitude__c,
        //         c.Longitude__c
        //     );

        //     ClientOptionDTO dto = new ClientOptionDTO();
        //     dto.id         = c.Id;
        //     dto.name       = c.Name;
        //     dto.distanceKm = distKm;

        //     options.add(dto);
        // }

        // Sort by distance ascending (manual selection sort)
        sortClientsByDistance(options);

        // Trim to limitSize
        if (options.size() > limitSize) {
            List<ClientOptionDTO> trimmed = new List<ClientOptionDTO>();
            for (Integer i = 0; i < limitSize; i++) {
                trimmed.add(options[i]);
            }
            options = trimmed;
        }

        return options;

    }

    // Insert item into targetList keeping it sorted by distanceKm ascending, max size = maxSize
    public static void insertSortedClient(List<ClientOptionDTO> targetList, ClientOptionDTO item, Integer maxSize) {
        if (item == null || item.distanceKm == null) {
            return;
        }

        Integer pos = 0;
        while (pos < targetList.size() && targetList[pos].distanceKm <= item.distanceKm) {
            pos++;
        }

        // Insert at position
        targetList.add(pos, item);

        // // If list exceeds maxSize, drop the farthest one
        if (targetList.size() > maxSize) {
            targetList.remove(targetList.size() - 1);
        }
    }


    public static void sortClientsByDistance(List<ClientOptionDTO> items) {
    Integer n = items.size();
    for (Integer i = 0; i < n; i++) {
        Integer minIndex = i;

        for (Integer j = i + 1; j < n; j++) {
            Decimal dMin = items[minIndex].distanceKm;
            Decimal dJ   = items[j].distanceKm;

            if (dJ == null) {
                continue;
            }
            if (dMin == null || dJ < dMin) {
                minIndex = j;
            }
        }

        if (minIndex != i) {
            ClientOptionDTO tmp = items[i];
            items[i] = items[minIndex];
            items[minIndex] = tmp;
        }
    }
}


    // Haversine distance in KM
    private static Decimal calculateDistanceKm(
        Decimal lat1,
        Decimal lon1,
        Decimal lat2,
        Decimal lon2
    ) {
        Double dLat1 = (Double)lat1;
        Double dLon1 = (Double)lon1;
        Double dLat2 = (Double)lat2;
        Double dLon2 = (Double)lon2;

        Double rLat1 = dLat1 * Math.PI / 180;
        Double rLon1 = dLon1 * Math.PI / 180;
        Double rLat2 = dLat2 * Math.PI / 180;
        Double rLon2 = dLon2 * Math.PI / 180;

        Double dlat = rLat2 - rLat1;
        Double dlon = rLon2 - rLon1;

        Double a = Math.pow(Math.sin(dlat / 2), 2)
                 + Math.cos(rLat1) * Math.cos(rLat2)
                 * Math.pow(Math.sin(dlon / 2), 2);

        Double c = 2 * Math.asin(Math.min(1, Math.sqrt(a)));

        Double distance = 6371.0 * c; // Earth radius in km
        return (Decimal)distance;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getReasonForVisitOptions() {
        List<String> options = new List<String>();

        Schema.DescribeFieldResult fieldResult = Task_Log__c.Reason_for_Visit__c.getDescribe();

        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                options.add(entry.getLabel());
            }
        }

        return options;
    }

    // @AuraEnabled(cacheable=true)
    // public static List<String> getVisitTypePicVal() {
    //     List<String> options = new List<String>();

    //     Schema.DescribeFieldResult fieldResult = Task_Log__c.Visit_Type__c.getDescribe();

    //     List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

    //     for (Schema.PicklistEntry entry : picklistValues) {
    //         if (entry.isActive()) {
    //             options.add(entry.getLabel());
    //         }
    //     }

    //     return options;
    // }

    @AuraEnabled(cacheable=true)
    public static List<String> getPOCPicVal() {
        List<String> options = new List<String>();

        Schema.DescribeFieldResult fieldResult = Task_Log__c.Is_POC_available__c.getDescribe();

        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                options.add(entry.getLabel());
            }
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getVisitOutcomePicVal() {
        List<String> options = new List<String>();

        Schema.DescribeFieldResult fieldResult = Task_Log__c.Visit_outcome__c.getDescribe();

        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                options.add(entry.getLabel());
            }
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getNextActionPicVal() {
        List<String> options = new List<String>();

        Schema.DescribeFieldResult fieldResult = Task_Log__c.Next_Action__c.getDescribe();

        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                options.add(entry.getLabel());
            }
        }

        return options;
    }

    public class TaskValues {
        @AuraEnabled public Id id;
        @AuraEnabled public String customerName;
        @AuraEnabled public String customerCategory;
        @AuraEnabled public Boolean is100mOutside;
        @AuraEnabled public String customerType;
        @AuraEnabled public Id accountId;
    }

    @AuraEnabled
    public static List<TaskValues> taskDetails(String taskId, Decimal latitude, Decimal longitude){
        List<Task_Log__c> taskInfo = [
            SELECT Id, Latitude__c, Longitude__c, Customer_Type__c,
                   Lead__c, Lead__r.Name, Lead__r.Customer_Category__c,
                   Account__c, Account__r.Name,
                   Opportunity__c, Opportunity__r.Name, Opportunity__r.Customer_Category__c
            FROM Task_Log__c WHERE Id =: taskId LIMIT 1];

        List<TaskValues> tvList = new List<TaskValues>();
        if (taskInfo.isEmpty()) {
            return tvList;
        }

        TaskValues tv = new TaskValues();
        tv.Id = taskInfo[0].Id;
        tv.accountId = taskInfo[0].Account__c;

        String cType = taskInfo[0].Customer_Type__c;
        if (String.isNotBlank(cType)) {
            String lowerCT = cType.toLowerCase();
            if (lowerCT.contains('lead')) {
                tv.customerType = 'Lead';
            } else if (lowerCT.contains('opp')) {
                tv.customerType = 'Opportunity';
            } else if (lowerCT.contains('account') || lowerCT.contains('noenquiry')) {
                tv.customerType = 'Account';
            }
        }

        if (taskInfo[0].Lead__c != null) {
            tv.customerName = taskInfo[0].Lead__r.Name;
            tv.customerCategory = taskInfo[0].Lead__r.Customer_Category__c;
            tv.customerType = 'Lead';
        } else if (taskInfo[0].Opportunity__c != null) {
            tv.customerName = taskInfo[0].Opportunity__r.Name;
            tv.customerCategory = taskInfo[0].Opportunity__r.Customer_Category__c;
            if (String.isBlank(tv.customerType)) {
                tv.customerType = 'Opportunity';
            }
        } else if (taskInfo[0].Account__c != null) {
            tv.customerName = taskInfo[0].Account__r.Name;
            if (String.isBlank(tv.customerType)) {
                tv.customerType = 'Account';
            }
        }

        if (taskInfo[0].Latitude__c == null || taskInfo[0].Longitude__c == null
                || latitude == null || longitude == null) {
            tv.is100mOutside = false;
        } else {
            Double distance = calculateDistanceKm(
                latitude,
                longitude,
                taskInfo[0].Latitude__c,
                taskInfo[0].Longitude__c
            );

            System.debug('Distance: ' + distance);

            if (distance != null && distance > 0.3) {
                tv.is100mOutside = true; 
            } else {
                tv.is100mOutside = false;
            }
        }

        tvList.add(tv);
        return tvList;
    }

    @AuraEnabled
    public static void updateTask(String taskId, string VisitTypeValue, string pocValue, string visitOutcomeValue, 
            string nextActionValue, date followUpDate, string momValue, String selfieImageBase64, Decimal latitude,
            Decimal longitude, String fileName, String base64Data, string justificationValue){
        
        system.debug('taskId : '+taskId);
        if (taskId == null) {
            throw new AuraHandledException('TaskId is null');
        }

        if (momValue == '') {
            throw new AuraHandledException('MOM is required');
        }

        if (String.isNotBlank(fileName) && String.isNotBlank(base64Data)) {
            List<String> allowedTypes = new List<String>{
                'pdf','xls','xlsx','doc','docx','png','jpg','jpeg'
            };

            String extension = fileName.substringAfterLast('.').toLowerCase();

            if (!allowedTypes.contains(extension)) {
                throw new AuraHandledException('Invalid file type.');
            }
        }

        Savepoint sp = Database.setSavepoint();

        try {
            Task_Log__c tl = new Task_Log__c();
            tl.Id = taskId;
            tl.Visit_Type__c = VisitTypeValue;
            tl.Is_POC_available__c = pocValue;
            tl.Visit_outcome__c = visitOutcomeValue;
            tl.Next_Action__c = nextActionValue;
            tl.Next_Follow_Up_Date__c = followUpDate;
            tl.MOM__c = momValue;
            tl.IsCheckout__c = true;
            tl.Logged_Out_At__c = System.now();
            tl.Justification__c = justificationValue;
            if(justificationValue != null){
                tl.is100mOutside__c = true;
            }else{
                tl.is100mOutside__c = false;
            }
            

            if (latitude != null) {
                tl.Checked_Out_Latitude__c = latitude;
            }
            if (longitude != null) {
                tl.Checked_Out_Longitude__c = longitude;
            }

            update tl;

            //Insert File
            if (String.isNotBlank(fileName) && String.isNotBlank(base64Data)) {
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = EncodingUtil.base64Decode(base64Data);
                insert cv;

                // Link File to Task
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = [
                    SELECT ContentDocumentId 
                    FROM ContentVersion 
                    WHERE Id = :cv.Id
                ].ContentDocumentId;

                cdl.LinkedEntityId = taskId;
                cdl.ShareType = 'V';
                insert cdl;
            }

            //Attach selfie image if provided
            if (String.isNotBlank(selfieImageBase64)) {
                ContentVersion cv2 = new ContentVersion();
                String base64Data2 = selfieImageBase64;
                Integer commaIdx = selfieImageBase64.indexOf(',');
                if (commaIdx != -1) {
                    base64Data2 = selfieImageBase64.substring(commaIdx + 1);
                }
                cv2.VersionData            = EncodingUtil.base64Decode(base64Data2);
                cv2.Title                  = 'selfie_capture.jpg';
                cv2.PathOnClient           = 'selfie_capture.jpg';
                cv2.FirstPublishLocationId = taskId;
                insert cv2;
            }

        } catch (Exception e) {
            Database.rollback(sp);
            String userFriendlyMessage = getCleanErrorMessage(e.getMessage());
            AuraHandledException ex = new AuraHandledException(userFriendlyMessage);
            ex.setMessage(userFriendlyMessage);
            throw ex;
        }

    }

    // ---------------- NEW METHODS FOR VISIT JOURNEY ----------------

    @AuraEnabled(cacheable=true)
    public static List<TaskLogDTO> getScheduledVisits(Id employeeId) {
        if (employeeId == null) {
            return new List<TaskLogDTO>();
        }

        Id userId = employeeId;
        String idStr = String.valueOf(employeeId);
        if (!idStr.startsWith('005')) {
            // If employeeId is not a User ID, map custom Employee__c record to User
            List<Punch_Record__c> punches = [
                SELECT User__c 
                FROM Punch_Record__c 
                WHERE Employee__c = :employeeId AND User__c != null 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (!punches.isEmpty()) {
                userId = punches[0].User__c;
            } else {
                userId = UserInfo.getUserId();
            }
        }

        List<TaskLogDTO> dtos = new List<TaskLogDTO>();
        List<Task_Log__c> logs = [
            SELECT Id, Schedule_Date__c, Next_Action__c, Reason_for_Visit__c, Description__c,
                   Visit_Type__c, Client_Deatils__r.Name, Account__r.Name, Account__r.ParentId,
                   Account__r.Parent.Name, Lead__r.Name, Opportunity__r.Name,
                   Opportunity__r.AccountId, Opportunity__r.Account.Name,
                   Opportunity__r.Account.ParentId, Opportunity__r.Account.Parent.Name,
                   Customer_Type__c, Lead__c, Account__c, Opportunity__c,
                   Is_schedule__c, IsCancelled__c, Cancel_Reason__c
            FROM Task_Log__c
            WHERE (OwnerId = :userId OR CreatedById = :userId)
              AND (Is_schedule__c = true OR (IsCancelled__c = true AND Schedule_Date__c != null))
            ORDER BY Schedule_Date__c ASC, CreatedDate DESC
            LIMIT 200
        ];
        for (Task_Log__c tl : logs) {
            TaskLogDTO dto = new TaskLogDTO();
            dto.id = tl.Id;
            dto.nextAction = tl.Next_Action__c;
            dto.reasonForVisit = tl.Reason_for_Visit__c;
            dto.visitType = tl.Visit_Type__c;
            dto.followUpDate = tl.Schedule_Date__c;
            dto.description = tl.Description__c;
            dto.customerType = tl.Customer_Type__c;
            dto.leadId = tl.Lead__c;
            dto.leadName = tl.Lead__r != null ? tl.Lead__r.Name : null;
            dto.opportunityId = tl.Opportunity__c;
            dto.opportunityName = tl.Opportunity__r != null ? tl.Opportunity__r.Name : null;
            dto.isCancelled = (tl.IsCancelled__c == true);
            dto.cancelReason = tl.Cancel_Reason__c;

            // Visits scheduled from the Opportunity quick action only stamp
            // Opportunity__c, so fall back to the opportunity's head account.
            // If Account__c or Opportunity.AccountId is a Site, walk up to Parent.
            applyHeadAccount(dto, tl.Account__r);
            if (dto.accountId == null && tl.Opportunity__r != null) {
                applyHeadAccount(dto, tl.Opportunity__r.Account);
            }

            if (dto.opportunityId != null) {
                dto.associationType = 'Opportunity';
            } else if (dto.leadId != null) {
                dto.associationType = 'Lead';
            } else if (dto.accountId != null) {
                dto.associationType = 'Account';
            }

            // Resolve client name — priority: Opportunity > Account > Lead > Client_Details
            if (tl.Opportunity__r != null) {
                dto.clientName = tl.Opportunity__r.Name;
            } else if (tl.Account__r != null) {
                dto.clientName = tl.Account__r.Name;
            } else if (tl.Lead__r != null) {
                dto.clientName = tl.Lead__r.Name;
            } else if (tl.Client_Deatils__r != null) {
                dto.clientName = tl.Client_Deatils__r.Name;
            }
            
            dtos.add(dto);
        }
        return dtos;
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getOwnedLeads() {
        return [
            SELECT Id, Name, Company, Email, Phone, Status
            FROM Lead
            WHERE OwnerId = :UserInfo.getUserId()
            AND IsConverted = false
            AND Status IN ('Prospect', 'Prospecting')
            ORDER BY Name ASC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOwnedOpportunities() {
        return [
            SELECT Id, Name, AccountId, Account.Name, Account.ParentId, Account.Parent.Name, StageName
            FROM Opportunity
            WHERE OwnerId = :UserInfo.getUserId()
            AND StageName IN ('Nurture', 'Negotiation')
            ORDER BY Name ASC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<ClientOptionDTO> getNearbyAccounts(Decimal latitude, Decimal longitude) {
        if (latitude == null || longitude == null) {
            throw new AuraHandledException('Latitude and longitude are required.');
        }
        List<Account> accounts = [
            SELECT Id, Name, ParentId, Location__Latitude__s, Location__Longitude__s
            FROM Account
            WHERE Location__Latitude__s != null
            AND Location__Longitude__s != null
            LIMIT 1000
        ];

        List<ClientOptionDTO> options = new List<ClientOptionDTO>();
        for (Account a : accounts) {
            Decimal distKm = calculateDistanceKm(latitude, longitude, a.Location__Latitude__s, a.Location__Longitude__s);
            ClientOptionDTO dto = new ClientOptionDTO();
            dto.id = a.Id;
            dto.name = a.Name;
            dto.distanceKm = distKm;
            options.add(dto);
        }
        sortClientsByDistance(options);
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<ClientOptionDTO> getAllAccounts() {
        List<ClientOptionDTO> options = new List<ClientOptionDTO>();
        for (Account a : [SELECT Id, Name FROM Account ORDER BY Name ASC LIMIT 500]) {
            ClientOptionDTO dto = new ClientOptionDTO();
            dto.id = a.Id;
            dto.name = a.Name;
            dto.distanceKm = 0.0;
            options.add(dto);
        }
        return options;
    }

    @AuraEnabled
    public static Id createAccountOrSite(String name, Id parentId, Decimal lat, Decimal lng, String phone, String email) {
        try {
            Account a = new Account();
            a.Name = name;
            a.ParentId = parentId;
            if (String.isNotBlank(phone)) {
                a.Phone = phone;
            }
            if (String.isNotBlank(email)) {
                a.Email__c = email;
            }
            if (lat != null) {
                a.Location__Latitude__s = lat;
            }
            if (lng != null) {
                a.Location__Longitude__s = lng;
            }
            insert a;
            return a.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating Account/Site: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void createContactForAccount(String firstName, String lastName, String email, String phone, Id accountId) {
        try {
            Contact c = new Contact();
            c.FirstName = firstName;
            c.LastName = lastName;
            c.Email = email;
            c.Phone = phone;
            c.AccountId = accountId;
            insert c;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating Contact: ' + e.getMessage());
        }
    }

    public class CheckoutResult {
        @AuraEnabled public String status;
        @AuraEnabled public Id redirectId; // Opportunity ID, etc.
    }

    public static CheckoutResult updateTaskWithDisposition(
        String taskId, 
        String visitTypeValue, 
        String pocValue, 
        String visitOutcomeValue, 
        String nextActionValue, 
        Date followUpDate, 
        String momValue, 
        String selfieImageBase64, 
        Decimal latitude,
        Decimal longitude, 
        String fileName, 
        String base64Data, 
        String justificationValue,
        String postDisposition,
        String lostReason,
        String newContactFirstName,
        String newContactLastName,
        String newContactEmail,
        String newContactPhone,
        String remainingAccountPhone,
        String remainingAccountWebsite
    ) {
        return updateTaskWithDisposition(
            taskId, visitTypeValue, pocValue, visitOutcomeValue, nextActionValue, followUpDate, momValue, 
            selfieImageBase64, latitude, longitude, fileName, base64Data, justificationValue, postDisposition, 
            lostReason, newContactFirstName, newContactLastName, newContactEmail, newContactPhone, 
            remainingAccountPhone, remainingAccountWebsite, null, null, 'Visit', null
        );
    }

    public static CheckoutResult updateTaskWithDisposition(
        String taskId, 
        String visitTypeValue, 
        String pocValue, 
        String visitOutcomeValue, 
        String nextActionValue, 
        Date followUpDate, 
        String momValue, 
        String selfieImageBase64, 
        Decimal latitude,
        Decimal longitude, 
        String fileName, 
        String base64Data, 
        String justificationValue,
        String postDisposition,
        String lostReason,
        String newContactFirstName,
        String newContactLastName,
        String newContactEmail,
        String newContactPhone,
        String remainingAccountPhone,
        String remainingAccountWebsite,
        String selectedContactId
    ) {
        return updateTaskWithDisposition(
            taskId, visitTypeValue, pocValue, visitOutcomeValue, nextActionValue, followUpDate, momValue, 
            selfieImageBase64, latitude, longitude, fileName, base64Data, justificationValue, postDisposition, 
            lostReason, newContactFirstName, newContactLastName, newContactEmail, newContactPhone, 
            remainingAccountPhone, remainingAccountWebsite, null, selectedContactId, 'Visit', null
        );
    }

    @AuraEnabled
    public static CheckoutResult updateTaskWithDisposition(
        String taskId, 
        String visitTypeValue, 
        String pocValue, 
        String visitOutcomeValue, 
        String nextActionValue, 
        Date followUpDate, 
        String momValue, 
        String selfieImageBase64, 
        Decimal latitude,
        Decimal longitude, 
        String fileName, 
        String base64Data, 
        String justificationValue,
        String postDisposition, // Mark Lead as Lost, Convert Lead, Edit Opportunity, Create Lead, Create Opportunity, No Action
        String lostReason,
        String newContactFirstName,
        String newContactLastName,
        String newContactEmail,
        String newContactPhone,
        String remainingAccountPhone,
        String remainingAccountEmail,
        String remainingAccountContactName,
        String selectedContactId,
        String followUpType,
        String customerCategory
    ) {
        if (taskId == null) {
            throw new AuraHandledException('TaskId is null');
        }
        if (String.isBlank(momValue)) {
            throw new AuraHandledException('MOM is required');
        }
        if (followUpDate == null) {
            throw new AuraHandledException('Next Follow Up Date is required.');
        }
        if (followUpDate < Date.today()) {
            throw new AuraHandledException('Next Follow Up Date cannot be a past date.');
        }

        Savepoint sp = Database.setSavepoint();
        CheckoutResult res = new CheckoutResult();
        res.status = 'Success';

        try {
            // 1. Query the Task_Log__c
            Task_Log__c tl = [
                SELECT Id, Lead__c, Account__c, Opportunity__c, Reason_for_Visit__c, Customer_Type__c,
                       Lead__r.Customer_Category__c, Opportunity__r.Customer_Category__c,
                       Latitude__c, Longitude__c, Address_Book__c,
                       Address_Book__r.Street__c, Address_Book__r.City__c,
                       Address_Book__r.State__c, Address_Book__r.Country__c,
                       Address_Book__r.PIN__c, Address_Book__r.Zone__c
                FROM Task_Log__c
                WHERE Id = :taskId
                LIMIT 1
            ];

            // 2. Perform Checkout updates on the Task Log
            tl.Visit_Type__c = visitTypeValue;
            tl.Is_POC_available__c = pocValue;
            tl.Visit_outcome__c = visitOutcomeValue;
            tl.Next_Action__c = nextActionValue;
            tl.Next_Follow_Up_Date__c = followUpDate;
            tl.MOM__c = momValue;
            tl.IsCheckout__c = true;
            tl.Logged_Out_At__c = System.now();
            /* tl.Justification__c = justificationValue;
            tl.is100mOutside__c = (justificationValue != null); */

            tl.Justification__c = justificationValue;

            Boolean isOutside = false;

            if (tl.Latitude__c != null &&
                tl.Longitude__c != null &&
                latitude != null &&
                longitude != null) {

                Decimal distanceKm = calculateDistanceKm(
                    tl.Latitude__c,
                    tl.Longitude__c,
                    latitude,
                    longitude
                );

                isOutside = distanceKm != null && distanceKm > 0.3;
            }

            tl.is100mOutside__c = isOutside;

            if (latitude != null) {
                tl.Checked_Out_Latitude__c = latitude;
            }
            if (longitude != null) {
                tl.Checked_Out_Longitude__c = longitude;
            } 

            update tl;

            // 3. Attach file if provided
            if (String.isNotBlank(fileName) && String.isNotBlank(base64Data)) {
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = EncodingUtil.base64Decode(base64Data);
                insert cv;

                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = [
                    SELECT ContentDocumentId 
                    FROM ContentVersion 
                    WHERE Id = :cv.Id
                ].ContentDocumentId;
                cdl.LinkedEntityId = taskId;
                cdl.ShareType = 'V';
                insert cdl;
            }

            // 4. Attach selfie if provided
            if (String.isNotBlank(selfieImageBase64)) {
                ContentVersion cvSelfie = new ContentVersion();
                String base64Data2 = selfieImageBase64;
                Integer commaIdx = selfieImageBase64.indexOf(',');
                if (commaIdx != -1) {
                    base64Data2 = selfieImageBase64.substring(commaIdx + 1);
                }
                cvSelfie.VersionData            = EncodingUtil.base64Decode(base64Data2);
                cvSelfie.Title                  = 'selfie_capture.jpg';
                cvSelfie.PathOnClient           = 'selfie_capture.jpg';
                cvSelfie.FirstPublishLocationId = taskId;
                insert cvSelfie;
            }

            Id finalContactId = null;
            if (String.isNotBlank(selectedContactId) && selectedContactId != 'new') {
                finalContactId = selectedContactId;
            }

            // 5. Create Contact if POC is available
            Id activeAccountId = tl.Account__c;
            if (activeAccountId != null && (String.isBlank(selectedContactId) || selectedContactId == 'new')) {
                if (String.isNotBlank(newContactFirstName) || String.isNotBlank(newContactLastName)) {
                    Contact c = new Contact();
                    c.FirstName = newContactFirstName;
                    c.LastName = String.isBlank(newContactLastName) ? 'Unknown' : newContactLastName;
                    c.Email = newContactEmail;
                    c.Phone = newContactPhone;
                    c.AccountId = activeAccountId;
                    if (tl.Address_Book__c != null && tl.Address_Book__r != null) {
                        applyAddressBookToContact(c, tl.Address_Book__r);
                    }
                    try {
                        insert c;
                    } catch (Exception contactEx) {
                        c.Street__c = null;
                        c.City__c = null;
                        c.State__c = null;
                        c.Country__c = null;
                        c.PIN__c = null;
                        c.Zone__c = null;
                        insert c;
                    }
                    finalContactId = c.Id;
                }
            }

            // 6. Handle Remaining Account Details
            if (activeAccountId != null && (String.isNotBlank(remainingAccountPhone) || String.isNotBlank(remainingAccountEmail))) {
                Account accToUpdate = new Account(Id = activeAccountId);
                if (String.isNotBlank(remainingAccountPhone)) {
                    accToUpdate.Phone = remainingAccountPhone;
                }
                if (String.isNotBlank(remainingAccountEmail)) {
                    try {
                        accToUpdate.put('Email__c', remainingAccountEmail);
                    } catch (Exception ex) {
                        System.debug('Account Email__c field does not exist: ' + ex.getMessage());
                    }
                }
                update accToUpdate;
            }

            // Keep Account address in sync with the visit Address Book (new Account / Create Lead / Create Opportunity).
            if (activeAccountId != null) {
                Address_Book__c visitAddress = tl.Address_Book__r;
                if (visitAddress == null) {
                    List<Address_Book__c> accountBooks = [
                        SELECT Street__c, City__c, State__c, Country__c, PIN__c, Zone__c
                        FROM Address_Book__c
                        WHERE Account__c = :activeAccountId
                        ORDER BY CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!accountBooks.isEmpty()) {
                        visitAddress = accountBooks[0];
                    }
                }
                if (visitAddress != null) {
                    Account accForAddress = [
                        SELECT Id, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                               Street__c, City__c, State__c, Country__c, PIN__c, Zone__c
                        FROM Account
                        WHERE Id = :activeAccountId
                        LIMIT 1
                    ];
                    stampAccountBillingFromAddressBook(accForAddress, visitAddress);
                }
            }

            // Stamp Customer Category only when the related record does not already have one.
            if (String.isNotBlank(customerCategory)) {
                if (tl.Lead__c != null && String.isBlank(tl.Lead__r.Customer_Category__c)) {
                    try {
                        Lead ld = new Lead(Id = tl.Lead__c, Customer_Category__c = customerCategory);
                        update ld;
                    } catch (Exception ex) {
                        System.debug('Lead Customer_Category__c update failed: ' + ex.getMessage());
                    }
                } else if (tl.Opportunity__c != null && String.isBlank(tl.Opportunity__r.Customer_Category__c)) {
                    try {
                        Opportunity opp = new Opportunity(Id = tl.Opportunity__c);
                        opp.put('Customer_Category__c', customerCategory);
                        update opp;
                    } catch (Exception ex) {
                        System.debug('Opp Customer_Category__c update failed: ' + ex.getMessage());
                    }
                } else if (tl.Account__c != null && tl.Lead__c == null && tl.Opportunity__c == null) {
                    try {
                        Account acc = new Account(Id = tl.Account__c);
                        acc.put('Customer_Category__c', customerCategory);
                        update acc;
                    } catch (Exception ex) {
                        System.debug('Account Customer_Category__c update failed: ' + ex.getMessage());
                    }
                }
            }

            // Related Opportunity for follow-up Call/Event (visit Opp, or Opp created at checkout)
            Id relatedOpportunityId = tl.Opportunity__c;
            Id relatedLeadId = tl.Lead__c;

            // -------------------------------------------
            Boolean opportunityCreatedAtCheckout = false;

            // 7. Handle Post-Checkout Dispositions
            if (postDisposition == 'Mark Lead as Lost' && tl.Lead__c != null) {
                Lead ld = new Lead(Id = tl.Lead__c);
                ld.Status = 'Lost';
                try {
                    ld.put('Lost_Reason__c', lostReason);
                } catch (Exception ex) {
                    System.debug('Lost_Reason__c field does not exist: ' + ex.getMessage());
                }
                update ld;
            } 
            else if (postDisposition == 'Convert Lead' && tl.Lead__c != null) {
                res.redirectId = tl.Lead__c;
            } 
            else if (postDisposition == 'Edit Opportunity' && tl.Opportunity__c != null) {
                res.redirectId = tl.Opportunity__c;
            }
            else if (postDisposition == 'Create Lead' && activeAccountId != null) {
                Account activeAcc = [
                    SELECT Name, Phone, Email__c, Location__Latitude__s, Location__Longitude__s,
                    BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                    FROM Account
                    WHERE Id = :activeAccountId
                    LIMIT 1
                ];
                Contact poc = queryCheckoutContact(finalContactId);

                Lead newLd = new Lead();
                String leadFirstName = firstNonBlank(new List<String>{
                    poc != null ? poc.FirstName : null,
                    newContactFirstName
                });
                String leadLastName = firstNonBlank(new List<String>{
                    poc != null ? poc.LastName : null,
                    newContactLastName,
                    remainingAccountContactName,
                    'Enquiry'
                });
                if (String.isNotBlank(leadFirstName)) {
                    newLd.FirstName = leadFirstName;
                }
                newLd.LastName = leadLastName;
                newLd.Company = activeAcc.Name;
                newLd.Company_Name__c = activeAcc.Name;
                newLd.Account__c = activeAccountId;
                newLd.Status = 'Prospect';
                newLd.LeadSource = 'Offline Marketing';
                if (String.isNotBlank(customerCategory)) {
                    newLd.Customer_Category__c = customerCategory;
                } else {
                    newLd.Customer_Category__c = 'EPC';
                }
                newLd.UOM__c = 'Metric Ton';
                newLd.Quantity__c = 1;
                newLd.Phone = firstNonBlank(new List<String>{
                    poc != null ? poc.Phone : null,
                    newContactPhone,
                    poc != null ? poc.MobilePhone : null,
                    remainingAccountPhone,
                    activeAcc.Phone
                });
                newLd.Email = firstNonBlank(new List<String>{
                    poc != null ? poc.Email : null,
                    newContactEmail,
                    remainingAccountEmail,
                    activeAcc.Email__c
                });
                String salespersonDept = departmentNameForRunningUser(Lead.Department_Name__c);
                if (String.isNotBlank(salespersonDept)) {
                    newLd.Department_Name__c = salespersonDept;
                }

                if (activeAcc.Location__Latitude__s != null) {
                    newLd.Location__Latitude__s = activeAcc.Location__Latitude__s;
                }
                if (activeAcc.Location__Longitude__s != null) {
                    newLd.Location__Longitude__s = activeAcc.Location__Longitude__s;
                }

                // lead address
                newLd.Street = activeAcc.BillingStreet != null ? activeAcc.BillingStreet : null;
                newLd.City = activeAcc.BillingCity != null ? activeAcc.BillingCity : null;
                newLd.State = activeAcc.BillingState != null ? activeAcc.BillingState : null;
                newLd.PostalCode = activeAcc.BillingPostalCode != null ? activeAcc.BillingPostalCode : null;
                newLd.Country = activeAcc.BillingCountry != null ? activeAcc.BillingCountry : null;

                if (tl.Address_Book__c != null && tl.Address_Book__r != null) {
                    applyAddressBookToLead(newLd, tl.Address_Book__r);
                }
                try {
                    insert newLd;
                } catch (Exception leadEx) {
                    newLd.Street__c = null;
                    newLd.City__c = null;
                    newLd.State__c = null;
                    newLd.Country__c = null;
                    newLd.PIN__c = null;
                    newLd.Zone__c = null;
                    insert newLd;
                }
                relatedLeadId = newLd.Id;
                res.redirectId = newLd.Id;
                // ---------------------------------------------------------
                // For Create Lead, the Task_Log__c should be associated
                // only with the newly created Lead, not the Account.
                tl.Lead__c = newLd.Id;
                tl.Account__c = null;
                update tl;
            }
            /* else if (postDisposition == 'Create Opportunity' && activeAccountId != null) {
                Account activeAcc = [SELECT Name FROM Account WHERE Id = :activeAccountId LIMIT 1];
                Opportunity newOpp = new Opportunity();
                newOpp.Name = activeAcc.Name + ' - Opp';
                newOpp.AccountId = activeAccountId;
                newOpp.StageName = 'Nurture';
                newOpp.CloseDate = Date.today().addDays(30);
                if (String.isNotBlank(customerCategory)) {
                    try {
                        newOpp.put('Customer_Category__c', customerCategory);
                    } catch (Exception e) {}
                }
                String salespersonDept = departmentNameForRunningUser(Opportunity.Department_Name__c);
                if (String.isNotBlank(salespersonDept)) {
                    try {
                        newOpp.put('Department_Name__c', salespersonDept);
                    } catch (Exception e) {}
                }
                insert newOpp;
                relatedOpportunityId = newOpp.Id;
                res.redirectId = newOpp.Id;
            } */
            else if (postDisposition == 'Create Opportunity' && activeAccountId != null) {

                Account activeAcc = [
                    SELECT Name
                    FROM Account
                    WHERE Id = :activeAccountId
                    LIMIT 1
                ];

                // Get department of the running user
                String salespersonDept =
                    departmentNameForRunningUser(Opportunity.Department_Name__c);

                Opportunity newOpp = new Opportunity();

                // Opportunity naming convention:
                // {departmentName}-{accountName}
                if (String.isNotBlank(salespersonDept)) {
                    newOpp.Name = salespersonDept + '-' + activeAcc.Name;
                } else {
                    // Fallback in case department cannot be resolved
                    newOpp.Name = activeAcc.Name;
                }

                newOpp.AccountId = activeAccountId;
                newOpp.StageName = 'Nurture';
                newOpp.CloseDate = Date.today().addDays(30);

                if (String.isNotBlank(customerCategory)) {
                    try {
                        newOpp.put('Customer_Category__c', customerCategory);
                    } catch (Exception e) {}
                }

                if (String.isNotBlank(salespersonDept)) {
                    try {
                        newOpp.put('Department_Name__c', salespersonDept);
                    } catch (Exception e) {}
                }

                insert newOpp;
                opportunityCreatedAtCheckout = true;

                relatedOpportunityId = newOpp.Id;
                res.redirectId = newOpp.Id;

                // ---------------------------------------------------------
                // For Create Opportunity, the Task_Log__c should be associated
                // only with the newly created Opportunity, not the Account.
                tl.Opportunity__c = newOpp.Id;
                tl.Account__c = null;
                update tl;

                // ---------------------------------------------------------
                // Add selected Contact to Opportunity Contact Roles
                // ---------------------------------------------------------
                if (finalContactId != null) {

                    List<OpportunityContactRole> existingRoles = [
                        SELECT Id
                        FROM OpportunityContactRole
                        WHERE OpportunityId = :newOpp.Id
                        AND ContactId = :finalContactId
                        LIMIT 1
                    ];

                    if (existingRoles.isEmpty()) {

                        // Check whether this Opportunity already has a primary contact
                        Integer primaryRoleCount = [
                            SELECT COUNT()
                            FROM OpportunityContactRole
                            WHERE OpportunityId = :newOpp.Id
                            AND IsPrimary = true
                        ];

                        OpportunityContactRole newRole = new OpportunityContactRole();

                        newRole.OpportunityId = newOpp.Id;
                        newRole.ContactId = finalContactId;
                        newRole.Role = 'Contact';
                        newRole.IsPrimary = (primaryRoleCount == 0);

                        insert newRole;
                    }
                }
            }


            if (relatedOpportunityId != null
                && finalContactId != null
                && !opportunityCreatedAtCheckout) {

                List<OpportunityContactRole> existingRoles = [
                    SELECT Id
                    FROM OpportunityContactRole
                    WHERE OpportunityId = :relatedOpportunityId
                    AND ContactId = :finalContactId
                    LIMIT 1
                ];

                if (existingRoles.isEmpty()) {

                    Integer primaryRoleCount = [
                        SELECT COUNT()
                        FROM OpportunityContactRole
                        WHERE OpportunityId = :relatedOpportunityId
                        AND IsPrimary = true
                    ];

                    OpportunityContactRole newRole = new OpportunityContactRole();

                    newRole.OpportunityId = relatedOpportunityId;
                    newRole.ContactId = finalContactId;
                    newRole.Role = 'Contact';
                    newRole.IsPrimary = (primaryRoleCount == 0);

                    insert newRole;
                }
            }

            // 8. Create Scheduled Visit (Task_Log__c) or Standard Call (Task) or Event if followUpDate is specified
            if (followUpDate != null) {
                if (followUpType == 'Call') {
                    if (relatedOpportunityId != null) {
                        List<Task> existingCalls = [
                            SELECT Id, Subject, Description, Status, Disposition__c
                            FROM Task
                            WHERE WhatId = :relatedOpportunityId
                              AND (TaskSubtype = 'Call' OR Subject LIKE '%Call%')
                              AND Status != 'Completed'
                              AND IsClosed = false
                        ];
                        if (!existingCalls.isEmpty()) {
                            String formattedDate = followUpDate.format();
                            String appendMsg = 'Another call has been scheduled at the following date: ' + formattedDate;
                            for (Task t : existingCalls) {
                                t.Status = 'Completed';
                                t.Disposition__c = 'Not Connected';
                                if (String.isNotBlank(t.Description)) {
                                    t.Description = t.Description + '\n' + appendMsg;
                                } else {
                                    t.Description = appendMsg;
                                }
                            }
                            update existingCalls;
                        }
                    }

                    Task callTask = new Task();
                    callTask.Subject = 'Call';
                    callTask.TaskSubtype = 'Call';
                    callTask.ActivityDate = followUpDate;
                    callTask.Status = 'Not Started';
                    callTask.Priority = 'Normal';
                    callTask.Description = 'Follow up Call Details:\n' + momValue;
                    // Opportunity selected/created → link via WhatId (Contact WhoId allowed; Lead WhoId is not)
                    if (relatedOpportunityId != null) {
                        callTask.WhatId = relatedOpportunityId;
                        if (finalContactId != null) {
                            callTask.WhoId = finalContactId;
                        }
                    } else if (finalContactId != null) {
                        callTask.WhoId = finalContactId;
                    } else if (relatedLeadId != null) {
                        callTask.WhoId = relatedLeadId;
                    }
                    insert callTask;
                } else if (followUpType == 'Event') {
                    if (relatedOpportunityId != null) {
                        List<Event> existingEvents = [
                            SELECT Id, Subject, Description, Disposition__c, Close_Date__c
                            FROM Event
                            WHERE WhatId = :relatedOpportunityId
                              AND (Disposition__c = null OR Disposition__c NOT IN ('Completed', 'Not Completed'))
                        ];
                        if (!existingEvents.isEmpty()) {
                            String formattedDate = followUpDate.format();
                            String appendMsg = 'Another event has been scheduled at the following date: ' + formattedDate;
                            for (Event ev : existingEvents) {
                                ev.Disposition__c = 'Not Completed';
                                ev.Close_Date__c = System.now();
                                if (String.isNotBlank(ev.Description)) {
                                    ev.Description = ev.Description + '\n' + appendMsg;
                                } else {
                                    ev.Description = appendMsg;
                                }
                            }
                            update existingEvents;
                        }
                    }

                    Event evt = new Event();
                    evt.Subject = 'Meeting';
                    evt.Type = 'Meeting';
                    evt.StartDateTime = Datetime.newInstance(followUpDate, Time.newInstance(10, 0, 0, 0));
                    evt.EndDateTime = Datetime.newInstance(followUpDate, Time.newInstance(11, 0, 0, 0));
                    evt.ActivityDate = followUpDate;
                    evt.DurationInMinutes = 60;
                    evt.Description = 'Follow up Event Details:\n' + momValue;
                    evt.IsReminderSet = true;
                    evt.ReminderDateTime = Datetime.newInstance(followUpDate, Time.newInstance(9, 45, 0, 0));
                    evt.OwnerId = UserInfo.getUserId();
                    if (relatedOpportunityId != null) {
                        evt.WhatId = relatedOpportunityId;
                        if (finalContactId != null) {
                            evt.WhoId = finalContactId;
                        }
                    } else if (finalContactId != null) {
                        evt.WhoId = finalContactId;
                    } else if (relatedLeadId != null) {
                        evt.WhoId = relatedLeadId;
                    }
                    insert evt;
                } else { // default 'Visit'
                    Task_Log__c schTask = new Task_Log__c();
                    schTask.Is_schedule__c = true;
                    schTask.Schedule_Date__c = followUpDate;
                    schTask.Next_Action__c = nextActionValue;
                    schTask.Reason_for_Visit__c = String.isNotBlank(nextActionValue) ? nextActionValue : 'Follow up';
                    schTask.Description__c = momValue;
                    schTask.MOM__c = momValue;
                    schTask.Customer_Type__c = tl.Customer_Type__c;
                    schTask.Lead__c = relatedLeadId;
                    schTask.Opportunity__c = relatedOpportunityId;
                    schTask.Account__c = tl.Account__c;

                    if (String.isBlank(schTask.Customer_Type__c)) {
                        if (schTask.Lead__c != null) schTask.Customer_Type__c = 'Lead';
                        else if (schTask.Opportunity__c != null) schTask.Customer_Type__c = 'Opportunity';
                        else if (schTask.Account__c != null) schTask.Customer_Type__c = 'Account';
                    }

                    insert schTask;
                }
            }

            // 9. Alert the department HOD when check-out is outside the geofence.
            // Runs last so it only fires once every save above has succeeded.
            if (isOutside) {
                notifyHodOfGeofenceBreach(tl.Id, tl.Latitude__c, tl.Longitude__c, latitude, longitude);
            }

            return res;
        } catch (Exception e) {
            Database.rollback(sp);
            String userFriendlyMessage = getCleanErrorMessage(e.getMessage());
            AuraHandledException ex = new AuraHandledException(userFriendlyMessage);
            ex.setMessage(userFriendlyMessage);
            throw ex;
        }
    }

    // ---------------- GEOFENCE BREACH ALERT ----------------

    @TestVisible private static final String GEOFENCE_NOTIFICATION_TYPE = 'Geofence_Breach_Alert';
    @TestVisible private static final String GEOFENCE_EMAIL_TEMPLATE = 'Geofence_Breach_HOD_Alert';
    @TestVisible private static final String HOD_PROFILE_NAME = 'Utkarsh HOD';
    @TestVisible private static final String GEOFENCE_SENDER_EMAIL = 'noreply@utkarshindialimited.in';

    /**
     * Sends a custom notification and an email to the HOD(s) of the running
     * user's department (User.Department) when a visit is checked out outside
     * the geofence. Never throws: a failed alert must not fail the checkout.
     */
    @TestVisible
    private static void notifyHodOfGeofenceBreach(
        Id taskLogId,
        Decimal checkInLatitude,
        Decimal checkInLongitude,
        Decimal checkOutLatitude,
        Decimal checkOutLongitude
    ) {
        try {
            if (taskLogId == null) {
                return;
            }

            User currentUser = [
                SELECT Id, Name, Department
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            if (String.isBlank(currentUser.Department)) {
                return;
            }

            List<User> hods = [
                SELECT Id, Name, Email
                FROM User
                WHERE Profile.Name = :HOD_PROFILE_NAME
                  AND Department = :currentUser.Department
                  AND IsActive = true
                WITH SYSTEM_MODE
            ];
            if (hods.isEmpty()) {
                return;
            }

            Task_Log__c log = [
                SELECT Id, Name, Justification__c,
                       Opportunity__r.Name, Account__r.Name, Lead__r.Name, Client_Deatils__r.Name
                FROM Task_Log__c
                WHERE Id = :taskLogId
                LIMIT 1
            ];

            String customerName = 'Unknown Customer';
            if (log.Opportunity__r != null) {
                customerName = log.Opportunity__r.Name;
            } else if (log.Account__r != null) {
                customerName = log.Account__r.Name;
            } else if (log.Lead__r != null) {
                customerName = log.Lead__r.Name;
            } else if (log.Client_Deatils__r != null) {
                customerName = log.Client_Deatils__r.Name;
            }

            String distanceText = '';
            if (checkInLatitude != null && checkInLongitude != null
                    && checkOutLatitude != null && checkOutLongitude != null) {
                Decimal distanceKm = calculateDistanceKm(
                    checkInLatitude, checkInLongitude, checkOutLatitude, checkOutLongitude
                );
                distanceText = ' ' + distanceKm.setScale(2) + ' km';
            }

            String justification = String.isNotBlank(log.Justification__c)
                ? log.Justification__c
                : 'Not provided';

            String title = 'Geofence Breach Alert';
            String body = currentUser.Name + ' checked out of the visit with ' + customerName
                + distanceText + ' away from the check-in location. Justification: ' + justification;

            Set<String> recipientIds = new Set<String>();
            for (User hod : hods) {
                recipientIds.add(hod.Id);
            }

            // Custom notification (bell + mobile push)
            try {
                List<CustomNotificationType> types = [
                    SELECT Id
                    FROM CustomNotificationType
                    WHERE DeveloperName = :GEOFENCE_NOTIFICATION_TYPE
                    LIMIT 1
                ];
                if (!types.isEmpty()) {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle(title);
                    notification.setBody(body);
                    notification.setNotificationTypeId(types[0].Id);
                    notification.setTargetId(log.Id);
                    notification.send(recipientIds);
                } else {
                    System.debug('Custom notification type not found: ' + GEOFENCE_NOTIFICATION_TYPE);
                }
            } catch (Exception notifyEx) {
                System.debug('Geofence custom notification failed: ' + notifyEx.getMessage());
            }

            // Email (Lightning email template, plain fallback if the template is missing)
            try {
                // Lightning templates built in the UI get a numeric suffix on
                // their API name, so match on the prefix.
                String templatePrefix = GEOFENCE_EMAIL_TEMPLATE + '%';
                List<EmailTemplate> templates = [
                    SELECT Id
                    FROM EmailTemplate
                    WHERE DeveloperName LIKE :templatePrefix
                      AND IsActive = true
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                List<OrgWideEmailAddress> owea = [
                    SELECT Id
                    FROM OrgWideEmailAddress
                    WHERE Address = :GEOFENCE_SENDER_EMAIL
                    LIMIT 1
                ];
                Id oweaId = owea.isEmpty() ? null : owea[0].Id;

                List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
                for (User hod : hods) {
                    String subject = title + ': ' + currentUser.Name;
                    String htmlBody = body.escapeHtml4();
                    String textBody = body;

                    if (!templates.isEmpty()) {
                        // A User recipient cannot take a WhatId, so render with the
                        // Task Log as context first and send the rendered content.
                        Messaging.SingleEmailMessage rendered =
                            Messaging.renderStoredEmailTemplate(templates[0].Id, hod.Id, log.Id);
                        subject = rendered.getSubject();
                        htmlBody = rendered.getHtmlBody();
                        textBody = rendered.getPlainTextBody();
                    } else {
                        System.debug('Email template not found: ' + GEOFENCE_EMAIL_TEMPLATE);
                    }

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTargetObjectId(hod.Id);
                    mail.setSaveAsActivity(false);
                    if (oweaId != null) {
                        mail.setOrgWideEmailAddressId(oweaId);
                    }
                    mail.setSubject(subject);
                    if (String.isNotBlank(htmlBody)) {
                        mail.setHtmlBody(htmlBody);
                    }
                    if (String.isNotBlank(textBody)) {
                        mail.setPlainTextBody(textBody);
                    }
                    emails.add(mail);
                }

                if (!emails.isEmpty()) {
                    Messaging.sendEmail(emails, false);
                }
            } catch (Exception emailEx) {
                System.debug('Geofence email failed: ' + emailEx.getMessage());
            }
        } catch (Exception e) {
            System.debug('Geofence HOD alert failed: ' + e.getMessage());
        }
    }

    private static String getValidCustomerType(String customerType) {
        if (String.isBlank(customerType)) {
            return customerType;
        }
        try {
            Schema.DescribeFieldResult fieldResult = Task_Log__c.Customer_Type__c.getDescribe();
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            String targetKey = customerType.toLowerCase().replaceAll('\\s+', '');
            
            // Try direct match or common substring match
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.isActive()) {
                    String val = entry.getValue();
                    String valNorm = val.toLowerCase().replaceAll('\\s+', '');
                    if (valNorm == targetKey) {
                        return val;
                    }
                }
            }
            
            // Try mapped prefixes
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.isActive()) {
                    String val = entry.getValue();
                    String valLower = val.toLowerCase();
                    if (targetKey == 'leads' && valLower.contains('lead')) {
                        return val;
                    }
                    if (targetKey == 'opps' && (valLower.contains('opp') || valLower.contains('opportunity'))) {
                        return val;
                    }
                    if (targetKey == 'noenquiry' && (valLower.contains('no') || valLower.contains('enquiry'))) {
                        return val;
                    }
                }
            }
            
            // Fallback to first active picklist value
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.isActive()) {
                    return entry.getValue();
                }
            }
        } catch (Exception e) {
            System.debug('Error describing Customer_Type__c: ' + e.getMessage());
        }
        return customerType;
    }

    public static String getCleanErrorMessage(String rawMessage) {
        if (String.isBlank(rawMessage)) {
            return 'An unexpected error occurred.';
        }
        String cleanMsg = rawMessage;
        
        // Handle Validation Rules
        if (cleanMsg.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION,')) {
            cleanMsg = cleanMsg.substringAfter('FIELD_CUSTOM_VALIDATION_EXCEPTION,');
        }
        // Handle Restricted Picklists
        else if (cleanMsg.contains('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST,')) {
            cleanMsg = cleanMsg.substringAfter('INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST,');
        }
        
        // Remove common DML formatting wrappers
        if (cleanMsg.contains(': []')) {
            cleanMsg = cleanMsg.replace(': []', '');
        }
        
        return cleanMsg.trim();
    }

    @AuraEnabled
    public static void rescheduleScheduledVisit(Id visitId, String reason, Date nextDate) {
        try {
            if (visitId == null) {
                throw new AuraHandledException('Visit ID is required.');
            }
            Task_Log__c tl = [
                SELECT Id, Schedule_Date__c, Reschedule_Reason__c, isRescheduled__c 
                FROM Task_Log__c 
                WHERE Id = :visitId 
                LIMIT 1
            ];
            tl.Schedule_Date__c = nextDate;
            // String timeStr = String.isNotBlank(nextTime) ? ' (Time: ' + nextTime + ')' : '';
            // tl.Reschedule_Reason__c = String.isNotBlank(reason) ? reason + timeStr : 'Rescheduled' + timeStr;
            tl.Reschedule_Reason__c = String.isNotBlank(reason) ? reason + String.valueOf(nextDate) : 'Rescheduled' + String.valueOf(nextDate);
            tl.isRescheduled__c = true;
            update tl;
        } catch (Exception e) {
            throw new AuraHandledException(getCleanErrorMessage(e.getMessage()));
        }
    }

    @AuraEnabled
    public static void cancelScheduledVisit(Id visitId, String reason, Date nextDate) {
        try {
            if (visitId == null) {
                throw new AuraHandledException('Visit ID is required.');
            }
            Task_Log__c tl = [
                SELECT Id, Is_schedule__c, Visit_Status__c, Reschedule_Reason__c, Cancel_Reason__c, IsCancelled__c 
                FROM Task_Log__c 
                WHERE Id = :visitId 
                LIMIT 1
            ];
            tl.Is_schedule__c = false;
            tl.Visit_Status__c = 'Not Completed';
            
            // Format cancel detail
            String cancelDetail = (String.isNotBlank(reason) ? reason : 'No reason provided');
            if (nextDate != null) {
                cancelDetail += ' | Next proposed date: ' + nextDate.format();
            }
            /* if (String.isNotBlank(nextTime)) {
                cancelDetail += ' ' + nextTime;
            } */
            
            // tl.Reschedule_Reason__c = cancelDetail;
            tl.Cancel_Reason__c = cancelDetail;
            tl.IsCancelled__c = true;
            update tl;
        } catch (Exception e) {
            throw new AuraHandledException(getCleanErrorMessage(e.getMessage()));
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCustomerCategoryOptions() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult = Lead.Customer_Category__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.isActive()) {
                options.add(entry.getLabel());
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchKey) {
        if (String.isBlank(searchKey)) {
            return [
                SELECT Id, Name, Phone
                FROM Account
                WHERE ParentId = null
                ORDER BY Name ASC
                LIMIT 50
            ];
        }
        String queryKey = '%' + searchKey + '%';
        return [
            SELECT Id, Name, Phone
            FROM Account
            WHERE ParentId = null
              AND (Name LIKE :queryKey OR Phone LIKE :queryKey)
            ORDER BY Name ASC
            LIMIT 50
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> searchOpportunities(String searchKey) {
        if (String.isBlank(searchKey)) {
            return [
                SELECT Id, Name, AccountId, Account.Name, Account.ParentId, Account.Parent.Name, StageName
                FROM Opportunity
                WHERE OwnerId = :UserInfo.getUserId()
                  AND StageName IN ('Nurture', 'Negotiation')
                ORDER BY Name ASC
                LIMIT 50
            ];
        }
        String queryKey = '%' + searchKey + '%';
        return [
            SELECT Id, Name, AccountId, Account.Name, Account.ParentId, Account.Parent.Name, StageName
            FROM Opportunity
            WHERE OwnerId = :UserInfo.getUserId()
              AND StageName IN ('Nurture', 'Negotiation')
              AND (Name LIKE :queryKey OR Account.Phone LIKE :queryKey OR Account.Email__c LIKE :queryKey)
            ORDER BY Name ASC
            LIMIT 50
        ];
    }

    @AuraEnabled
    public static List<Account> getEligibleSites(Id parentAccountId, Decimal latitude, Decimal longitude) {
        List<Account> allSites = [
            SELECT Id, Name, Location__Latitude__s, Location__Longitude__s
            FROM Account
            WHERE ParentId = :parentAccountId
        ];
        
        List<Account> eligible = new List<Account>();
        for (Account a : allSites) {
            if (a.Location__Latitude__s == null || a.Location__Longitude__s == null) {
                eligible.add(a);
            } else if (latitude != null && longitude != null) {
                Decimal dist = calculateDistanceMeters(latitude, longitude, a.Location__Latitude__s, a.Location__Longitude__s);
                if (dist <= 200.0) {
                    eligible.add(a);
                }
            }
        }
        return eligible;
    }

    @AuraEnabled
    public static Map<String, Object> checkAddressBook(Id accountId, Decimal latitude, Decimal longitude) {
        Map<String, Object> res = new Map<String, Object>();
        if (accountId == null || latitude == null || longitude == null) {
            res.put('found', false);
            return res;
        }

        List<Address_Book__c> books = [
            SELECT Id, Street__c, City__c, PIN__c, State__c, latitude__c, longitude__c
            FROM Address_Book__c
            WHERE Account__c = :accountId
              AND latitude__c != null
              AND longitude__c != null
        ];

        for (Address_Book__c ab : books) {
            Decimal abLat = parseCoordinate(ab.latitude__c);
            Decimal abLng = parseCoordinate(ab.longitude__c);
            if (abLat == null || abLng == null) {
                continue;
            }
            Decimal dist = calculateDistanceMeters(latitude, longitude, abLat, abLng);
            if (dist != null && dist <= 200.0) {
                res.put('found', true);
                res.put('addressBookId', ab.Id);
                res.put('address', composeAddressBookDisplay(ab));
                return res;
            }
        }

        res.put('found', false);
        return res;
    }

    public static Address_Book__c buildAddressBookFromGeocode(
        Id accountId,
        Id opportunityId,
        Decimal latitude,
        Decimal longitude,
        MapboxGeocodeService.GeocodeResult geo,
        String descriptionFallback,
        String accountNameFallback
    ) {
        Address_Book__c ab = new Address_Book__c();
        ab.Account__c = accountId;
        if (opportunityId != null) {
            ab.Opportunity__c = opportunityId;
        }
        ab.latitude__c = latitude != null ? String.valueOf(latitude) : null;
        ab.longitude__c = longitude != null ? String.valueOf(longitude) : null;

        if (geo != null) {
            ab.PIN__c = geo.pin;
            ab.City__c = geo.city;
            ab.Street__c = geo.street;
            ab.Country__c = matchPicklistValue(Address_Book__c.Country__c, geo.country);
            // State is controlled by Country — only set when Country matched
            if (ab.Country__c != null) {
                ab.State__c = matchPicklistValue(Address_Book__c.State__c, geo.state);
            }
            if (String.isBlank(ab.Street__c) && String.isNotBlank(geo.fullAddress)) {
                ab.Street__c = geo.fullAddress;
            }
        }

        if (String.isBlank(ab.Street__c)) {
            if (String.isNotBlank(descriptionFallback)) {
                ab.Street__c = descriptionFallback;
            } else if (String.isNotBlank(accountNameFallback)) {
                ab.Street__c = accountNameFallback;
            }
        }

        return ab;
    }

    /**
     * Copy Address Book fields onto Account address fields when those Account fields are blank.
     * Account page uses Street__c / City__c / State__c / Country__c / PIN__c / Zone__c.
     */
    public static void stampAccountBillingFromAddressBook(Account acc, Address_Book__c ab) {
        if (acc == null || acc.Id == null || ab == null) {
            return;
        }

        String country = matchPicklistValue(Account.Country__c, ab.Country__c);
        String state = matchPicklistValue(Account.State__c, ab.State__c);
        String zone = matchPicklistValue(Account.Zone__c, ab.Zone__c);

        Account toUpdate = new Account(Id = acc.Id);
        Boolean changed = false;

        if (String.isBlank(acc.Street__c) && String.isNotBlank(ab.Street__c)) {
            toUpdate.Street__c = ab.Street__c;
            changed = true;
        }
        if (String.isBlank(acc.City__c) && String.isNotBlank(ab.City__c)) {
            toUpdate.City__c = ab.City__c;
            changed = true;
        }
        if (String.isBlank(acc.PIN__c) && String.isNotBlank(ab.PIN__c)) {
            toUpdate.PIN__c = ab.PIN__c;
            changed = true;
        }
        if (String.isBlank(acc.Country__c) && String.isNotBlank(country)) {
            toUpdate.Country__c = country;
            changed = true;
        }
        if (String.isBlank(acc.State__c) && String.isNotBlank(state)) {
            toUpdate.State__c = state;
            changed = true;
        }
        if (String.isBlank(acc.Zone__c) && String.isNotBlank(zone)) {
            toUpdate.Zone__c = zone;
            changed = true;
        }
        if (String.isBlank(acc.BillingStreet) && String.isNotBlank(ab.Street__c)) {
            toUpdate.BillingStreet = ab.Street__c;
            changed = true;
        }
        if (String.isBlank(acc.BillingCity) && String.isNotBlank(ab.City__c)) {
            toUpdate.BillingCity = ab.City__c;
            changed = true;
        }
        if (String.isBlank(acc.BillingPostalCode) && String.isNotBlank(ab.PIN__c)) {
            toUpdate.BillingPostalCode = ab.PIN__c;
            changed = true;
        }

        if (!changed) {
            return;
        }

        try {
            update toUpdate;
        } catch (Exception e) {
            try {
                Account retry = new Account(Id = acc.Id);
                if (String.isNotBlank(ab.Street__c)) {
                    retry.Street__c = ab.Street__c;
                    retry.BillingStreet = ab.Street__c;
                }
                if (String.isNotBlank(ab.City__c)) {
                    retry.City__c = ab.City__c;
                    retry.BillingCity = ab.City__c;
                }
                if (String.isNotBlank(ab.PIN__c)) {
                    retry.PIN__c = ab.PIN__c;
                    retry.BillingPostalCode = ab.PIN__c;
                }
                if (String.isNotBlank(zone)) {
                    retry.Zone__c = zone;
                }
                update retry;
            } catch (Exception retryEx) {
                System.debug('Account address stamp from visit address failed: ' + retryEx.getMessage());
            }
        }
    }

    public static void applyAddressBookToContact(Contact c, Address_Book__c ab) {
        if (c == null || ab == null) {
            return;
        }
        if (String.isNotBlank(ab.Street__c)) {
            c.Street__c = ab.Street__c;
        }
        if (String.isNotBlank(ab.City__c)) {
            c.City__c = ab.City__c;
        }
        if (String.isNotBlank(ab.PIN__c)) {
            c.PIN__c = ab.PIN__c;
        }
        String country = matchPicklistValue(Contact.Country__c, ab.Country__c);
        if (String.isNotBlank(country)) {
            c.Country__c = country;
        }
        String state = matchPicklistValue(Contact.State__c, ab.State__c);
        if (String.isNotBlank(state)) {
            c.State__c = state;
        }
        String zone = matchPicklistValue(Contact.Zone__c, ab.Zone__c);
        if (String.isNotBlank(zone)) {
            c.Zone__c = zone;
        }
    }

    public static void applyAddressBookToLead(Lead ld, Address_Book__c ab) {
        if (ld == null || ab == null) {
            return;
        }
        if (String.isNotBlank(ab.Street__c)) {
            ld.Street__c = ab.Street__c;
        }
        if (String.isNotBlank(ab.City__c)) {
            ld.City__c = ab.City__c;
        }
        if (String.isNotBlank(ab.PIN__c)) {
            ld.PIN__c = ab.PIN__c;
        }
        String country = matchPicklistValue(Lead.Country__c, ab.Country__c);
        if (String.isNotBlank(country)) {
            ld.Country__c = country;
        }
        String state = matchPicklistValue(Lead.State__c, ab.State__c);
        if (String.isNotBlank(state)) {
            ld.State__c = state;
        }
        String zone = matchPicklistValue(Lead.Zone__c, ab.Zone__c);
        if (String.isNotBlank(zone)) {
            ld.Zone__c = zone;
        }
    }

    private static Contact queryCheckoutContact(Id contactId) {
        if (contactId == null) {
            return null;
        }
        List<Contact> contacts = [
            SELECT FirstName, LastName, Phone, Email, MobilePhone
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        return contacts.isEmpty() ? null : contacts[0];
    }

    private static String firstNonBlank(List<String> values) {
        if (values == null) {
            return null;
        }
        for (String value : values) {
            if (String.isNotBlank(value)) {
                return value.trim();
            }
        }
        return null;
    }

    public static String departmentNameForRunningUser(Schema.SObjectField departmentField) {
        User runningUser = [
            SELECT Department, Departments__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        String matched = matchPicklistValue(departmentField, runningUser.Department);
        if (String.isNotBlank(matched)) {
            return matched;
        }
        matched = matchDepartmentLoosely(departmentField, runningUser.Department);
        if (String.isNotBlank(matched)) {
            return matched;
        }
        if (String.isNotBlank(runningUser.Departments__c)) {
            for (String token : runningUser.Departments__c.split(';')) {
                matched = matchDepartmentLoosely(departmentField, token);
                if (String.isNotBlank(matched)) {
                    return matched;
                }
            }
        }
        return null;
    }

    public static String matchDepartmentLoosely(Schema.SObjectField departmentField, String rawValue) {
        if (String.isBlank(rawValue) || departmentField == null) {
            return null;
        }
        String needle = rawValue.trim().toLowerCase().replace('_', ' ').replace('-', ' ');
        String best = null;
        Integer bestLen = 0;
        for (Schema.PicklistEntry pe : departmentField.getDescribe().getPicklistValues()) {
            if (!pe.isActive()) {
                continue;
            }
            String valueNorm = pe.getValue().toLowerCase();
            String labelNorm = pe.getLabel().toLowerCase();
            Boolean hit = needle.contains(valueNorm) || valueNorm.contains(needle)
                || needle.contains(labelNorm) || labelNorm.contains(needle);
            if (hit && pe.getValue().length() > bestLen) {
                best = pe.getValue();
                bestLen = pe.getValue().length();
            }
        }
        return best;
    }

    private static Id resolveHeadAccountId(Account acc, Id fallbackId) {
        if (acc != null && acc.ParentId != null) {
            return acc.ParentId;
        }
        return acc != null ? acc.Id : fallbackId;
    }

    private static void applyHeadAccount(TaskLogDTO dto, Account acc) {
        if (dto == null || acc == null) {
            return;
        }
        if (acc.ParentId != null) {
            dto.accountId = acc.ParentId;
            dto.accountName = acc.Parent != null ? acc.Parent.Name : acc.Name;
        } else {
            dto.accountId = acc.Id;
            dto.accountName = acc.Name;
        }
    }

    private static String composeAddressBookDisplay(Address_Book__c ab) {
        if (ab == null) {
            return '';
        }
        List<String> parts = new List<String>();
        if (String.isNotBlank(ab.Street__c)) {
            parts.add(ab.Street__c);
        }
        if (String.isNotBlank(ab.City__c)) {
            parts.add(ab.City__c);
        }
        if (String.isNotBlank(ab.PIN__c)) {
            parts.add(ab.PIN__c);
        }
        return String.join(parts, ', ');
    }

    private static Decimal parseCoordinate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static String matchPicklistValue(Schema.SObjectField fieldToken, String rawValue) {
        if (String.isBlank(rawValue) || fieldToken == null) {
            return null;
        }
        String trimmed = rawValue.trim();
        for (Schema.PicklistEntry pe : fieldToken.getDescribe().getPicklistValues()) {
            if (pe.isActive() && (pe.getValue().equalsIgnoreCase(trimmed) || pe.getLabel().equalsIgnoreCase(trimmed))) {
                return pe.getValue();
            }
        }
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactsForAccount(Id accountId) {
        if (accountId == null) {
            return new List<Contact>();
        }
        return [
            SELECT Id, FirstName, LastName, Name, Email, Phone 
            FROM Contact 
            WHERE AccountId = :accountId 
            ORDER BY Name ASC
        ];
    }

    public static Decimal calculateDistanceMeters(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2) {
        Decimal distKm = calculateDistanceKm(lat1, lon1, lat2, lon2);
        if (distKm == null) {
            return null;
        }
        return distKm * 1000;
    }

    @AuraEnabled(cacheable=true)
    public static List<Punch_Record__c> getApprovedWfhWfoRequestsToday(Id employeeId) {
        if (employeeId == null) {
            return new List<Punch_Record__c>();
        }
        
        Id targetUserId = employeeId;
        String idStr = String.valueOf(employeeId);
        if (!idStr.startsWith('005')) {
            List<Punch_Record__c> punches = [
                SELECT User__c 
                FROM Punch_Record__c 
                WHERE Employee__c = :employeeId AND User__c != null 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            if (!punches.isEmpty()) {
                targetUserId = punches[0].User__c;
            } else {
                targetUserId = UserInfo.getUserId();
            }
        }
        
        return [
            SELECT Id, Is_WFH_Request__c, Is_WFO_Request__c, WFH_Request_Date__c,
                   WFH_Request_Start_Time__c, WFH_Request_End_Time__c
            FROM Punch_Record__c
            WHERE User__c = :targetUserId
              AND (Is_WFH_Request__c = true OR Is_WFO_Request__c = true)
              AND WFH_Request_Date__c = TODAY
              AND WFH_Approval_Status__c = 'Approved'
            ORDER BY CreatedDate DESC
        ];
    }
}