public class NewExpenseFormController {

    @AuraEnabled(cacheable=true)
    public static Travel_Eligibility_Matrix__c getEligibility() {
        try {
            User currentUser = [
                SELECT Id, Employee_Level__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (String.isBlank(currentUser.Employee_Level__c)) {
                throw buildAuraException('Employee Level is not set on your user record. Please contact admin.');
            }

            List<Travel_Eligibility_Matrix__c> matrices = [
                SELECT Id, Name, Level__c, Grade__c, Designations__c,
                       Lodging_Tier_1__c, Lodging_Tier_2__c, Lodging_Tier_3__c,
                       Fooding_Tier_1__c, Fooding_Tier_2__c, Fooding_Tier_3__c,
                       Air_Business_Class__c, Air_Economy_Class__c,
                       Train_1AC__c, Train_2AC__c, Train_3AC__c, Train_Sleeper__c,
                       Ola_Uber_Taxi__c, Car_Rental__c, Auto__c, Bus__c,
                       Own_2_Wheeler_Rate_per_KM__c, Own_4_Wheeler_Rate_per_KM__c
                FROM Travel_Eligibility_Matrix__c
                WHERE Level__c = :currentUser.Employee_Level__c
                LIMIT 1
            ];

            if (matrices.isEmpty()) {
                throw buildAuraException(
                    'No Travel Eligibility Matrix found for level ' + currentUser.Employee_Level__c + '.'
                );
            }

            return matrices[0];
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw buildAuraException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Expense_Line__c> getPrivateVehicleExpenseLines(Date startDate, Date endDate) {
        try {
            Id currentUserId = UserInfo.getUserId();
            if (startDate == null || endDate == null) {
                return new List<Expense_Line__c>();
            }
            DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));

            return [
                SELECT Id, Name, Date__c, Start_Date__c, AI_Extracted_Distance__c, Manually_Extracted_Distance__c,
                       Vehicle_Type__c, Amount__c, Expense__c, Description__c, Punch_Record__c, Expense_Type__c
                FROM Expense_Line__c
                WHERE (
                    Expense__r.Employee__c = :currentUserId 
                    OR Expense__r.OwnerId = :currentUserId 
                    OR CreatedById = :currentUserId 
                    OR Expense__r.CreatedById = :currentUserId
                )
                  AND (
                      Expense__r.Status__c = 'New' 
                      OR Expense__r.Status__c = 'Draft' 
                      OR Expense__r.Status__c = null
                  )
                  AND (
                      Expense__r.Is_Private_Vehicle_Expense__c = true 
                      OR Expense_Type__c = 'Own Vehicle' 
                      OR Expense_Type__c = 'Private Vehicle'
                      OR Is_Private_Vehicle_Expense__c = true
                  )
                  AND (
                      (Date__c >= :startDate AND Date__c <= :endDate)
                      OR (Start_Date__c >= :startDate AND Start_Date__c <= :endDate)
                      OR (Date__c = null AND Start_Date__c = null AND CreatedDate >= :startDateTime AND CreatedDate <= :endDateTime)
                  )
                ORDER BY Date__c ASC, Start_Date__c ASC, CreatedDate ASC
            ];
        } catch (Exception e) {
            throw buildAuraException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String saveExpenseData(String payload) {
        try {
            ExpensePayload data = (ExpensePayload) JSON.deserialize(payload, ExpensePayload.class);

            Id currentUserId = UserInfo.getUserId();
            User currentUser = [SELECT Id, Employee_Level__c, ManagerId, Department, Profile.Name FROM User WHERE Id = :currentUserId LIMIT 1];

            Id approverId = resolveApproverId(currentUser);

            if (data.endDate != null) {
                Date today = Date.today();
                Integer currentYear = today.year();
                Integer currentMonth = today.month();
                Integer currentDay = today.day();

                Integer endYear = data.endDate.year();
                Integer endMonth = data.endDate.month();

                Integer monthDiff = (currentYear - endYear) * 12 + (currentMonth - endMonth);
                if (monthDiff == 1) {
                    if (currentDay > 5) {
                        throw buildAuraException('Expenses for the previous month can only be submitted up to the 5th of the current month.');
                    }
                } else if (monthDiff > 1) {
                    throw buildAuraException('Expenses for past months can only be submitted up to the 5th of the immediately following month.');
                }
            }

            String initialStatus = resolveInitialStatus(currentUser);

            Expense__c exp = new Expense__c();
            exp.Subject__c = data.subject;
            exp.Travel_Start_Date__c = data.startDate;
            exp.Travel_End_Date__c = data.endDate;
            exp.Status__c = initialStatus;
            exp.Employee__c = currentUserId;
            exp.Employee_Level__c = currentUser.Employee_Level__c;
            exp.Approver__c = approverId;
            exp.User_Department__c = currentUser.Department != null ? currentUser.Department : null;
            exp.Submitted_Date__c = Date.today();

            insert exp;

            List<Expense_Line__c> linesToInsert = new List<Expense_Line__c>();
            if (data.lines != null && !data.lines.isEmpty()) {
                for (ExpenseLineWrapper lineData : data.lines) {
                    Expense_Line__c line = new Expense_Line__c();
                    line.Expense__c = exp.Id;
                    String expType = lineData.expenseType;
                    if (expType == 'Private Vehicle') {
                        expType = 'Own Vehicle';
                    }
                    line.Expense_Type__c = expType;
                    line.Amount__c = lineData.amount;
                    line.Approved_Amount__c = lineData.amount;
                    line.Start_Date__c = lineData.startDate;
                    line.End_Date__c = (lineData.expenseType == 'Lodging') ? lineData.endDate : null;
                    line.Justification__c = lineData.justification;
                    line.Miscellaneous_Cost__c = lineData.miscellaneousCost;
                    line.City__c = data.city;
                    line.City_Tier__c = data.cityTier;
                    line.Travel_Class__c = lineData.travelClass;
                    line.Vehicle_Type__c = lineData.vehicleType;
                    if (lineData.distanceKm != null) {
                        line.Distance_KM__c = lineData.distanceKm;
                    }

                    Boolean hasFiles = (lineData.files != null && !lineData.files.isEmpty()) 
                        || String.isNotBlank(lineData.documentId) 
                        || String.isNotBlank(lineData.base64Data);
                    if (hasFiles) {
                        line.Bill_Attached__c = true;
                    }
                    linesToInsert.add(line);
                }
                insert linesToInsert;

                linkLineFiles(data.lines, linesToInsert);
            }

            // Move selected Private Vehicle lines to the newly created Expense__c
            if (data.privateVehicleLineIds != null && !data.privateVehicleLineIds.isEmpty()) {
                List<Expense_Line__c> existingLines = [
                    SELECT Id, Expense__c, Amount__c, Approved_Amount__c 
                    FROM Expense_Line__c 
                    WHERE Id IN :data.privateVehicleLineIds
                ];

                Set<Id> oldExpenseIds = new Set<Id>();
                for (Expense_Line__c el : existingLines) {
                    if (el.Expense__c != null) {
                        oldExpenseIds.add(el.Expense__c);
                    }
                    el.Expense__c = exp.Id;
                    el.Approved_Amount__c = el.Amount__c;
                }

                try {
                    ExpenseLineTriggerHandler.isLwcContext = true;
                    update existingLines;

                    // Delete old Expense__c records if they no longer have any Expense_Line__c records
                    if (!oldExpenseIds.isEmpty()) {
                        List<Expense__c> oldExpensesToDelete = [
                            SELECT Id FROM Expense__c 
                            WHERE Id IN :oldExpenseIds 
                              AND Id NOT IN (SELECT Expense__c FROM Expense_Line__c WHERE Expense__c IN :oldExpenseIds)
                        ];
                        if (!oldExpensesToDelete.isEmpty()) {
                            delete oldExpensesToDelete;
                        }
                    }
                } finally {
                    ExpenseLineTriggerHandler.isLwcContext = false;
                }
            }

            Expense__c savedExp = [SELECT Name FROM Expense__c WHERE Id = :exp.Id LIMIT 1];
            return savedExp.Name;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw buildAuraException(e.getMessage());
        }
    }

    /**
     * Resolves the Id of the running user's expense from the Name returned by saveExpenseData,
     * so the form can navigate to the record after a new submission.
     */
    @AuraEnabled
    public static Id getMyExpenseIdByName(String expenseName) {
        if (String.isBlank(expenseName)) {
            return null;
        }
        List<Expense__c> expenses = [
            SELECT Id FROM Expense__c
            WHERE Name = :expenseName AND Employee__c = :UserInfo.getUserId()
            LIMIT 1
        ];
        return expenses.isEmpty() ? null : expenses[0].Id;
    }

    @AuraEnabled
    public static void discardFile(Id documentId) {
        if (documentId == null) {
            return;
        }
        try {
            delete [SELECT Id FROM ContentDocument WHERE Id = :documentId WITH SYSTEM_MODE LIMIT 1];
        } catch (Exception e) {
            throw buildAuraException('That file could not be removed: ' + e.getMessage());
        }
    }

    // ---------- Shared helpers (used by saveExpenseData and resubmitExpenseData) ----------

    public static final String FILE_TYPE_BILL = 'Bill';
    public static final String FILE_TYPE_PROOF = 'Proof';

    private static Id resolveApproverId(User currentUser) {
        List<User> hodUser = [
            SELECT Id FROM User WHERE Department = :currentUser.Department
            AND Profile.Name = 'Utkarsh HOD' LIMIT 1
        ];
        return hodUser.isEmpty() ? null : hodUser[0].Id;
    }

    private static String resolveInitialStatus(User currentUser) {
        String initialStatus = 'Pending HOD Approval';
        String userProfile = currentUser.Profile != null ? currentUser.Profile.Name : '';
        if (userProfile == 'Utkarsh HR') {
            initialStatus = 'Pending HR Approval';
        } else if (userProfile == 'System Administrator' || userProfile == 'Utkarsh Admin') {
            initialStatus = 'Pending ED Approval';
        }
        return initialStatus;
    }

    /**
     * Links uploaded files to their Expense_Line__c (lines[i] -> savedLines[i]), removes the
     * staging links from the user record and tags each file as Bill / Proof on ContentVersion.Description.
     * Files flagged isExisting (already linked, edit mode) and links that already exist are skipped.
     */
    private static void linkLineFiles(List<ExpenseLineWrapper> lines, List<Expense_Line__c> savedLines) {
        List<ContentVersion> cvList = new List<ContentVersion>();
        List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
        Set<Id> stagedDocIds = new Set<Id>();
        Map<Id, String> fileTypeByDocId = new Map<Id, String>();

        Set<Id> lineIds = new Map<Id, Expense_Line__c>(savedLines).keySet();
        Set<String> existingLinkKeys = new Set<String>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :lineIds
        ]) {
            existingLinkKeys.add(String.valueOf(link.ContentDocumentId) + String.valueOf(link.LinkedEntityId));
        }

        for (Integer i = 0; i < lines.size(); i++) {
            ExpenseLineWrapper lineData = lines[i];
            Id lineId = savedLines[i].Id;

            // Handle multiple files in files array
            if (lineData.files != null && !lineData.files.isEmpty()) {
                for (FileWrapper fw : lineData.files) {
                    if (fw.isExisting == true) {
                        continue;
                    }
                    if (String.isNotBlank(fw.documentId)) {
                        try {
                            Id docId = Id.valueOf(fw.documentId.trim());
                            if (!existingLinkKeys.contains(String.valueOf(docId) + String.valueOf(lineId))) {
                                cdlList.add(new ContentDocumentLink(
                                    ContentDocumentId = docId,
                                    LinkedEntityId    = lineId,
                                    ShareType         = 'V',
                                    Visibility        = 'AllUsers'
                                ));
                            }
                            stagedDocIds.add(docId);
                            if (fw.fileType == FILE_TYPE_BILL || fw.fileType == FILE_TYPE_PROOF) {
                                fileTypeByDocId.put(docId, fw.fileType);
                            }
                        } catch (Exception ex) {
                            System.debug(LoggingLevel.WARN, 'Invalid documentId: ' + fw.documentId);
                        }
                    } else if (String.isNotBlank(fw.base64Data)) {
                        ContentVersion cv = new ContentVersion();
                        cv.Title = fw.fileName;
                        String ext = String.isNotBlank(fw.extension) ? '.' + fw.extension : '';
                        cv.PathOnClient = fw.fileName + ext;
                        cv.VersionData = EncodingUtil.base64Decode(fw.base64Data);
                        cv.FirstPublishLocationId = lineId;
                        if (fw.fileType == FILE_TYPE_BILL || fw.fileType == FILE_TYPE_PROOF) {
                            cv.Description = fw.fileType;
                        }
                        cvList.add(cv);
                    }
                }
            } else if (String.isNotBlank(lineData.documentId)) {
                try {
                    Id docId = Id.valueOf(lineData.documentId.trim());
                    cdlList.add(new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId    = lineId,
                        ShareType         = 'V',
                        Visibility        = 'AllUsers'
                    ));
                    stagedDocIds.add(docId);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.WARN, 'Invalid documentId: ' + lineData.documentId);
                }
            } else if (String.isNotBlank(lineData.base64Data)) {
                // Backward compatibility for single file
                ContentVersion cv = new ContentVersion();
                cv.Title = lineData.fileName;
                String ext = String.isNotBlank(lineData.extension) ? '.' + lineData.extension : '';
                cv.PathOnClient = lineData.fileName + ext;
                cv.VersionData = EncodingUtil.base64Decode(lineData.base64Data);
                cv.FirstPublishLocationId = lineId;
                cvList.add(cv);
            }
        }

        if (!cdlList.isEmpty()) {
            insert cdlList;
        }
        if (!cvList.isEmpty()) {
            insert cvList;
        }

        // Clean up staging links from user record
        if (!stagedDocIds.isEmpty()) {
            List<ContentDocumentLink> stagingLinks = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :stagedDocIds
                  AND LinkedEntityId = :UserInfo.getUserId()
                WITH SYSTEM_MODE
            ];
            if (!stagingLinks.isEmpty()) {
                try {
                    delete stagingLinks;
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Staging link cleanup failed: ' + e.getMessage());
                }
            }
        }

        tagFileTypes(fileTypeByDocId);
    }

    /**
     * Stores Bill / Proof on the latest ContentVersion.Description so the file can be
     * placed back in the right section when a rejected expense is re-opened for edit.
     * Tagging is best-effort and never blocks the submission.
     */
    private static void tagFileTypes(Map<Id, String> fileTypeByDocId) {
        if (fileTypeByDocId.isEmpty()) {
            return;
        }
        try {
            List<ContentVersion> versions = [
                SELECT Id, ContentDocumentId, Description
                FROM ContentVersion
                WHERE ContentDocumentId IN :fileTypeByDocId.keySet()
                  AND IsLatest = true
            ];
            for (ContentVersion cv : versions) {
                cv.Description = fileTypeByDocId.get(cv.ContentDocumentId);
            }
            if (!versions.isEmpty()) {
                update versions;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'File type tagging failed: ' + e.getMessage());
        }
    }

    // =====================================================================
    // ===== EDIT MODE (rejected expense resubmission) =====================
    // Used only when newExpenseForm is opened with c__expenseId from myExpenses.
    // =====================================================================

    public static final String DRAFT_PV_PURPOSE = 'Market Visit - Own vehicle travel reimbursement';
    public static final String EDIT_NOT_ALLOWED_MSG = 'This expense cannot be edited. Only your own rejected expenses can be edited and resubmitted.';

    /**
     * Loads a rejected expense with its lines and line files for prefilling newExpenseForm.
     */
    @AuraEnabled
    public static ExpenseEditData getExpenseForEdit(Id expenseId) {
        try {
            Expense__c exp = getEditableExpense(expenseId);
            List<Expense_Line__c> lines = queryEditLines(exp.Id);

            Map<Id, List<ExpenseEditFile>> filesByLineId = queryLineFiles(new Map<Id, Expense_Line__c>(lines).keySet());

            ExpenseEditData result = new ExpenseEditData();
            result.expense = exp;
            result.lines = new List<ExpenseEditLine>();
            for (Expense_Line__c line : lines) {
                ExpenseEditLine editLine = new ExpenseEditLine();
                editLine.line = line;
                editLine.isPrivateVehicle = isPrivateVehicleLine(line);
                editLine.files = filesByLineId.containsKey(line.Id)
                    ? filesByLineId.get(line.Id)
                    : new List<ExpenseEditFile>();
                result.lines.add(editLine);
            }
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw buildAuraException(e.getMessage());
        }
    }

    /**
     * Saves the edited rejected expense and resubmits it for approval.
     * All line DML happens while the parent is still in its Rejected status, because
     * ExpenseLineTriggerHandler validates line edits against the parent's current status.
     * The header (status) is updated last.
     */
    @AuraEnabled
    public static String resubmitExpenseData(String payload) {
        try {
            ExpensePayload data = (ExpensePayload) JSON.deserialize(payload, ExpensePayload.class);
            Expense__c exp = getEditableExpense(data.expenseId);

            Id currentUserId = UserInfo.getUserId();
            User currentUser = [SELECT Id, Employee_Level__c, ManagerId, Department, Profile.Name FROM User WHERE Id = :currentUserId LIMIT 1];

            Map<Id, Expense_Line__c> currentLines = new Map<Id, Expense_Line__c>(queryEditLines(exp.Id));

            try {
                ExpenseLineTriggerHandler.isLwcContext = true;

                deleteRemovedEditFiles(data.removedDocumentIds, currentLines.keySet());
                deleteRemovedEditLines(data.removedLineIds, currentLines);
                saveEditedLines(exp, data, currentLines);
                reconcileEditPrivateVehicleLines(exp, currentUser, data, currentLines);
                updateResubmittedHeader(exp, data, currentUser);
            } finally {
                ExpenseLineTriggerHandler.isLwcContext = false;
            }

            return exp.Name;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw buildAuraException(e.getMessage());
        }
    }

    private static Expense__c getEditableExpense(Id expenseId) {
        if (expenseId == null) {
            throw buildAuraException(EDIT_NOT_ALLOWED_MSG);
        }
        List<Expense__c> expenses = [
            SELECT Id, Name, Subject__c, Status__c, Remark__c, Employee__c, Employee_Level__c,
                   Travel_Start_Date__c, Travel_End_Date__c
            FROM Expense__c
            WHERE Id = :expenseId
            LIMIT 1
        ];
        if (expenses.isEmpty()
            || expenses[0].Employee__c != UserInfo.getUserId()
            || !ExpenseTriggerHandler.isAllowedToReEditRejectedExpense(expenses[0].Status__c)) {
            throw buildAuraException(EDIT_NOT_ALLOWED_MSG);
        }
        return expenses[0];
    }

    private static List<Expense_Line__c> queryEditLines(Id expenseId) {
        return [
            SELECT Id, Name, Expense__c, Expense_Type__c, Amount__c, Approved_Amount__c,
                   Start_Date__c, End_Date__c, Date__c, Justification__c, Miscellaneous_Cost__c,
                   City__c, City_Tier__c, Travel_Class__c, Vehicle_Type__c, Distance_KM__c,
                   AI_Extracted_Distance__c, Manually_Extracted_Distance__c,
                   Is_Private_Vehicle_Expense__c, Description__c, Punch_Record__c
            FROM Expense_Line__c
            WHERE Expense__c = :expenseId
            // Lines of one claim are inserted in a single DML and share the same CreatedDate;
            // the auto-number Name keeps the original entry order (needed for Lodging overlap rows)
            ORDER BY CreatedDate ASC, Name ASC
        ];
    }

    private static Boolean isPrivateVehicleLine(Expense_Line__c line) {
        return line.Is_Private_Vehicle_Expense__c == true
            || line.Expense_Type__c == 'Own Vehicle'
            || line.Expense_Type__c == 'Private Vehicle';
    }

    private static Map<Id, List<ExpenseEditFile>> queryLineFiles(Set<Id> lineIds) {
        Map<Id, List<ExpenseEditFile>> filesByLineId = new Map<Id, List<ExpenseEditFile>>();
        if (lineIds.isEmpty()) {
            return filesByLineId;
        }

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :lineIds
        ];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        Map<Id, ContentVersion> versionByDocId = new Map<Id, ContentVersion>();
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT ContentDocumentId, Title, FileExtension, Description
                FROM ContentVersion
                WHERE ContentDocumentId IN :docIds AND IsLatest = true
            ]) {
                versionByDocId.put(cv.ContentDocumentId, cv);
            }
        }

        for (ContentDocumentLink link : links) {
            ContentVersion cv = versionByDocId.get(link.ContentDocumentId);
            if (cv == null) {
                continue;
            }
            ExpenseEditFile file = new ExpenseEditFile();
            file.documentId = link.ContentDocumentId;
            file.extension = cv.FileExtension;
            file.fileName = String.isNotBlank(cv.FileExtension) && cv.Title != null
                    && !cv.Title.toLowerCase().endsWith('.' + cv.FileExtension.toLowerCase())
                ? cv.Title + '.' + cv.FileExtension
                : cv.Title;
            // Files saved before Bill/Proof tagging was introduced default to Bill
            file.fileType = cv.Description == FILE_TYPE_PROOF ? FILE_TYPE_PROOF : FILE_TYPE_BILL;

            if (!filesByLineId.containsKey(link.LinkedEntityId)) {
                filesByLineId.put(link.LinkedEntityId, new List<ExpenseEditFile>());
            }
            filesByLineId.get(link.LinkedEntityId).add(file);
        }
        return filesByLineId;
    }

    /** Deletes existing files the user removed, only if they belong to a line of this expense. */
    private static void deleteRemovedEditFiles(List<Id> removedDocumentIds, Set<Id> expenseLineIds) {
        if (removedDocumentIds == null || removedDocumentIds.isEmpty() || expenseLineIds.isEmpty()) {
            return;
        }
        Set<Id> ownedDocIds = new Set<Id>();
        for (ContentDocumentLink link : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :expenseLineIds
              AND ContentDocumentId IN :removedDocumentIds
        ]) {
            ownedDocIds.add(link.ContentDocumentId);
        }
        if (!ownedDocIds.isEmpty()) {
            delete [SELECT Id FROM ContentDocument WHERE Id IN :ownedDocIds WITH SYSTEM_MODE];
        }
    }

    /** Deletes non Private Vehicle lines the user removed, only if they belong to this expense. */
    private static void deleteRemovedEditLines(List<Id> removedLineIds, Map<Id, Expense_Line__c> currentLines) {
        if (removedLineIds == null || removedLineIds.isEmpty()) {
            return;
        }
        List<Expense_Line__c> toDelete = new List<Expense_Line__c>();
        for (Id lineId : new Set<Id>(removedLineIds)) {
            Expense_Line__c line = currentLines.get(lineId);
            if (line != null && !isPrivateVehicleLine(line)) {
                toDelete.add(line);
                currentLines.remove(lineId);
            }
        }
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }

    /** Updates edited lines, inserts newly added lines and links their new files. */
    private static void saveEditedLines(Expense__c exp, ExpensePayload data, Map<Id, Expense_Line__c> currentLines) {
        if (data.lines == null || data.lines.isEmpty()) {
            return;
        }
        List<Expense_Line__c> savedInOrder = new List<Expense_Line__c>();
        List<Expense_Line__c> toUpdate = new List<Expense_Line__c>();
        List<Expense_Line__c> toInsert = new List<Expense_Line__c>();

        for (ExpenseLineWrapper lineData : data.lines) {
            Expense_Line__c line;
            if (lineData.lineId != null) {
                Expense_Line__c existing = currentLines.get(lineData.lineId);
                if (existing == null || isPrivateVehicleLine(existing)) {
                    throw buildAuraException('One of the expense lines no longer belongs to this expense. Please reload and try again.');
                }
                line = new Expense_Line__c(Id = existing.Id);
                toUpdate.add(line);
            } else {
                line = new Expense_Line__c(Expense__c = exp.Id);
                toInsert.add(line);
            }
            applyEditedLineFields(line, lineData, data);
            savedInOrder.add(line);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        linkLineFiles(data.lines, savedInOrder);
    }

    private static void applyEditedLineFields(Expense_Line__c line, ExpenseLineWrapper lineData, ExpensePayload data) {
        String expType = lineData.expenseType == 'Private Vehicle' ? 'Own Vehicle' : lineData.expenseType;
        line.Expense_Type__c = expType;
        line.Amount__c = lineData.amount;
        line.Approved_Amount__c = lineData.amount;
        line.Start_Date__c = lineData.startDate;
        line.End_Date__c = (lineData.expenseType == 'Lodging') ? lineData.endDate : null;
        line.Justification__c = lineData.justification;
        line.Miscellaneous_Cost__c = lineData.miscellaneousCost;
        line.City__c = data.city;
        line.City_Tier__c = data.cityTier;
        line.Travel_Class__c = lineData.travelClass;
        line.Vehicle_Type__c = lineData.vehicleType;
        line.Distance_KM__c = lineData.distanceKm;
        line.Bill_Attached__c = lineData.files != null && !lineData.files.isEmpty();
    }

    /**
     * Private Vehicle lines in edit mode:
     *  - ticked lines from other New/Draft expenses are moved onto this expense (old empty expenses are deleted)
     *  - ticked lines already on this expense stay, with Approved_Amount__c reset to Amount__c
     *  - unticked lines already on this expense move to one new 'New' expense (as PunchOutHandler creates them)
     */
    private static void reconcileEditPrivateVehicleLines(Expense__c exp, User currentUser, ExpensePayload data, Map<Id, Expense_Line__c> currentLines) {
        Set<Id> selectedIds = data.privateVehicleLineIds != null
            ? new Set<Id>(data.privateVehicleLineIds)
            : new Set<Id>();

        List<Expense_Line__c> keptLines = new List<Expense_Line__c>();
        List<Expense_Line__c> untickedLines = new List<Expense_Line__c>();
        for (Expense_Line__c line : currentLines.values()) {
            if (!isPrivateVehicleLine(line)) {
                continue;
            }
            if (selectedIds.contains(line.Id)) {
                keptLines.add(line);
            } else {
                untickedLines.add(line);
            }
        }

        // 1. Kept lines: approved amount follows amount (same as a fresh submission)
        List<Expense_Line__c> keptUpdates = new List<Expense_Line__c>();
        for (Expense_Line__c line : keptLines) {
            if (line.Approved_Amount__c != line.Amount__c) {
                keptUpdates.add(new Expense_Line__c(Id = line.Id, Approved_Amount__c = line.Amount__c));
            }
        }
        if (!keptUpdates.isEmpty()) {
            update keptUpdates;
        }

        // 2. Newly ticked lines from other New/Draft expenses of this user
        Set<Id> moveInIds = new Set<Id>(selectedIds);
        moveInIds.removeAll(currentLines.keySet());
        if (!moveInIds.isEmpty()) {
            Id currentUserId = currentUser.Id;
            List<Expense_Line__c> moveInLines = [
                SELECT Id, Expense__c, Amount__c, Approved_Amount__c
                FROM Expense_Line__c
                WHERE Id IN :moveInIds
                  AND (
                      Expense__r.Employee__c = :currentUserId
                      OR Expense__r.OwnerId = :currentUserId
                      OR CreatedById = :currentUserId
                      OR Expense__r.CreatedById = :currentUserId
                  )
                  AND (
                      Expense__r.Status__c = 'New'
                      OR Expense__r.Status__c = 'Draft'
                      OR Expense__r.Status__c = null
                  )
            ];
            Set<Id> oldExpenseIds = new Set<Id>();
            for (Expense_Line__c el : moveInLines) {
                if (el.Expense__c != null) {
                    oldExpenseIds.add(el.Expense__c);
                }
                el.Expense__c = exp.Id;
                el.Approved_Amount__c = el.Amount__c;
            }
            if (!moveInLines.isEmpty()) {
                update moveInLines;
            }
            if (!oldExpenseIds.isEmpty()) {
                List<Expense__c> oldExpensesToDelete = [
                    SELECT Id FROM Expense__c
                    WHERE Id IN :oldExpenseIds
                      AND Id NOT IN (SELECT Expense__c FROM Expense_Line__c WHERE Expense__c IN :oldExpenseIds)
                ];
                if (!oldExpensesToDelete.isEmpty()) {
                    delete oldExpensesToDelete;
                }
            }
        }

        // 3. Unticked lines go back to a 'New' Private Vehicle expense so they can be claimed later
        if (!untickedLines.isEmpty()) {
            Date earliestDate = null;
            for (Expense_Line__c line : untickedLines) {
                Date lineDate = line.Date__c != null ? line.Date__c : line.Start_Date__c;
                if (lineDate != null && (earliestDate == null || lineDate < earliestDate)) {
                    earliestDate = lineDate;
                }
            }
            Expense__c draftExp = new Expense__c(
                Employee__c                   = exp.Employee__c,
                Employee_Level__c             = currentUser.Employee_Level__c,
                Status__c                     = 'New',
                Purpose__c                    = DRAFT_PV_PURPOSE,
                Travel_Start_Date__c          = earliestDate != null ? earliestDate : Date.today(),
                Is_Private_Vehicle_Expense__c = true,
                Submitted_Date__c             = Date.today()
            );
            insert draftExp;

            List<Expense_Line__c> moveOut = new List<Expense_Line__c>();
            for (Expense_Line__c line : untickedLines) {
                moveOut.add(new Expense_Line__c(Id = line.Id, Expense__c = draftExp.Id));
            }
            update moveOut;
        }
    }

    /** Last step: header fields and status go back into the approval flow. Remark__c is kept as history. */
    private static void updateResubmittedHeader(Expense__c exp, ExpensePayload data, User currentUser) {
        Expense__c header = new Expense__c(Id = exp.Id);
        header.Subject__c = data.subject;
        header.Travel_Start_Date__c = data.startDate;
        header.Travel_End_Date__c = data.endDate;
        header.Status__c = resolveInitialStatus(currentUser);
        header.Approver__c = resolveApproverId(currentUser);
        header.User_Department__c = currentUser.Department != null ? currentUser.Department : null;
        header.Submitted_Date__c = Date.today();
        update header;
    }

    public class ExpenseEditData {
        @AuraEnabled public Expense__c expense;
        @AuraEnabled public List<ExpenseEditLine> lines;
    }

    public class ExpenseEditLine {
        @AuraEnabled public Expense_Line__c line;
        @AuraEnabled public Boolean isPrivateVehicle;
        @AuraEnabled public List<ExpenseEditFile> files;
    }

    public class ExpenseEditFile {
        @AuraEnabled public String documentId;
        @AuraEnabled public String fileName;
        @AuraEnabled public String extension;
        @AuraEnabled public String fileType;
    }

    // ===== END EDIT MODE =================================================

    private static AuraHandledException buildAuraException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    public class ExpensePayload {
        public String subject;
        public Date startDate;
        public Date endDate;
        public String city;
        public String cityTier;
        public List<ExpenseLineWrapper> lines;
        public List<Id> privateVehicleLineIds;
        // Edit mode (rejected expense resubmission) only
        public Id expenseId;
        public List<Id> removedLineIds;
        public List<Id> removedDocumentIds;
    }

    public class ExpenseLineWrapper {
        public String expenseType;
        public Decimal amount;
        public Date startDate;
        public Date endDate;
        public String justification;
        public String miscellaneousCost;
        public String travelClass;
        public String vehicleType;
        public Decimal distanceKm;
        public List<FileWrapper> files;
        // Edit mode only: Id of the existing Expense_Line__c being edited
        public Id lineId;
        // Backward compatibility properties
        public String fileName;
        public String base64Data;
        public String extension;
        public String documentId;
    }

    public class FileWrapper {
        public String fileName;
        public String base64Data;
        public String extension;
        public String fileType;
        public String documentId;
        // Edit mode only: file is already linked to the line
        public Boolean isExisting;
    }
}