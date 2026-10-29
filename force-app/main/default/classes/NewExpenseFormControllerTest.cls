@isTest
private class NewExpenseFormControllerTest {

    @TestSetup
    static void makeData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'nexu',
            Email = 'newexpense.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ExpenseUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'newexpense.user.' + DateTime.now().getTime() + '@example.com',
            Employee_Level__c = 'L6'
        );
        insert u;

        insert new Travel_Eligibility_Matrix__c(
            Name = 'L6 Matrix',
            Level__c = 'L6',
            Grade__c = 'A',
            Lodging_Tier_1__c = 5000,
            Lodging_Tier_2__c = 3000,
            Lodging_Tier_3__c = 2000,
            Fooding_Tier_1__c = 1000,
            Fooding_Tier_2__c = 800,
            Fooding_Tier_3__c = 500,
            Air_Economy_Class__c = true,
            Train_3AC__c = true,
            Own_2_Wheeler_Rate_per_KM__c = 4,
            Own_4_Wheeler_Rate_per_KM__c = 8
        );
    }

    private static User getTestUser() {
        return [SELECT Id FROM User WHERE Alias = 'nexu' LIMIT 1];
    }

    @isTest
    static void testGetEligibility_Success() {
        User u = getTestUser();
        System.runAs(u) {
            Test.startTest();
            Travel_Eligibility_Matrix__c matrix = NewExpenseFormController.getEligibility();
            Test.stopTest();
            System.assertNotEquals(null, matrix);
            System.assertEquals('L6', matrix.Level__c);
        }
    }

    @isTest
    static void testGetEligibility_NoLevel() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User noLevel = new User(
            Alias = 'nolvl',
            Email = 'nolevel.user@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'NoLevel',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'nolevel.user.' + DateTime.now().getTime() + '@example.com'
        );
        insert noLevel;

        System.runAs(noLevel) {
            Boolean threw = false;
            Test.startTest();
            try {
                NewExpenseFormController.getEligibility();
            } catch (AuraHandledException e) {
                threw = true;
                System.assert(e.getMessage().contains('Employee Level'), e.getMessage());
            }
            Test.stopTest();
            System.assert(threw, 'Should throw when Employee Level is blank');
        }
    }

    @isTest
    static void testSaveExpenseData_WithAttachment() {
        User u = getTestUser();
        System.runAs(u) {
            Map<String, Object> file1 = new Map<String, Object>{
                'fileName' => 'bill_1',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('fake-bill-1')),
                'extension' => 'pdf',
                'fileType' => 'Bill'
            };
            Map<String, Object> file2 = new Map<String, Object>{
                'fileName' => 'proof_1',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('fake-proof-1')),
                'extension' => 'png',
                'fileType' => 'Proof'
            };

            Map<String, Object> line = new Map<String, Object>{
                'expenseType' => 'Fooding',
                'amount' => 1200,
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today()),
                'justification' => 'Exceeded daily limit due to client dinner',
                'travelClass' => null,
                'vehicleType' => null,
                'distanceKm' => null,
                'files' => new List<Object>{ file1, file2 }
            };
            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Client Visit to Mumbai HQ',
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today().addDays(1)),
                'city' => 'Mumbai',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ line }
            };

            Test.startTest();
            String expenseName = NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, expenseName);
            List<Expense__c> expenses = [
                SELECT Id, Subject__c, Status__c, Employee_Level__c,
                       (SELECT Id, Expense_Type__c, Amount__c, Start_Date__c, End_Date__c, Justification__c, Bill_Attached__c FROM Expense_Lines__r)
                FROM Expense__c
                WHERE Employee__c = :u.Id
            ];
            System.assertEquals(1, expenses.size());
            System.assertEquals('Client Visit to Mumbai HQ', expenses[0].Subject__c);
            System.assertEquals('L6', expenses[0].Employee_Level__c);
            System.assertEquals(1, expenses[0].Expense_Lines__r.size());
            System.assertEquals(true, expenses[0].Expense_Lines__r[0].Bill_Attached__c);
            System.assertEquals(Date.today(), expenses[0].Expense_Lines__r[0].Start_Date__c);
            System.assertEquals(null, expenses[0].Expense_Lines__r[0].End_Date__c);
            System.assertEquals('Exceeded daily limit due to client dinner', expenses[0].Expense_Lines__r[0].Justification__c);

            List<ContentVersion> cvs = [
                SELECT Id, Title, FirstPublishLocationId 
                FROM ContentVersion 
                WHERE FirstPublishLocationId = :expenses[0].Expense_Lines__r[0].Id
            ];
            System.assertEquals(2, cvs.size());
        }
    }

    @isTest
    static void testSaveExpenseData_Lodging() {
        User u = getTestUser();
        System.runAs(u) {
            Map<String, Object> file = new Map<String, Object>{
                'fileName' => 'hotel_invoice',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('fake-hotel-bill')),
                'extension' => 'pdf',
                'fileType' => 'Bill'
            };
            Map<String, Object> line = new Map<String, Object>{
                'expenseType' => 'Lodging',
                'amount' => 4500,
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today().addDays(1)),
                'files' => new List<Object>{ file }
            };
            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Hotel stay for Mumbai audit',
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today().addDays(1)),
                'city' => 'Mumbai',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ line }
            };

            Test.startTest();
            String expenseName = NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, expenseName);
            Expense_Line__c savedLine = [
                SELECT Expense_Type__c, Amount__c, Start_Date__c, End_Date__c, Bill_Attached__c
                FROM Expense_Line__c
                WHERE Expense__r.Employee__c = :u.Id AND Expense_Type__c = 'Lodging'
                LIMIT 1
            ];
            System.assertEquals(4500, savedLine.Amount__c);
            System.assertEquals(Date.today(), savedLine.Start_Date__c);
            System.assertEquals(Date.today().addDays(1), savedLine.End_Date__c);
            System.assertEquals(true, savedLine.Bill_Attached__c);
        }
    }

    @isTest
    static void testSaveExpenseData_Miscellaneous() {
        User u = getTestUser();
        System.runAs(u) {
            Map<String, Object> file = new Map<String, Object>{
                'fileName' => 'courier_receipt',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('fake-courier-bill')),
                'extension' => 'pdf',
                'fileType' => 'Bill'
            };
            Map<String, Object> line = new Map<String, Object>{
                'expenseType' => 'Miscellaneous',
                'amount' => 350,
                'startDate' => String.valueOf(Date.today()),
                'endDate' => null,
                'miscellaneousCost' => 'Client documents courier charges',
                'files' => new List<Object>{ file }
            };
            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Courier of contracts to regional office',
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today()),
                'city' => 'Kolkata',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ line }
            };

            Test.startTest();
            String expenseName = NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, expenseName);
            Expense_Line__c savedLine = [
                SELECT Expense_Type__c, Amount__c, Miscellaneous_Cost__c, Start_Date__c, End_Date__c, Bill_Attached__c
                FROM Expense_Line__c
                WHERE Expense__r.Employee__c = :u.Id AND Expense_Type__c = 'Miscellaneous'
                LIMIT 1
            ];
            System.assertEquals(350, savedLine.Amount__c);
            System.assertEquals('Client documents courier charges', savedLine.Miscellaneous_Cost__c);
            System.assertEquals(Date.today(), savedLine.Start_Date__c);
            System.assertEquals(null, savedLine.End_Date__c);
            System.assertEquals(true, savedLine.Bill_Attached__c);
        }
    }

    @isTest
    static void testSaveExpenseData_Roadways() {
        User u = getTestUser();
        System.runAs(u) {
            Map<String, Object> file = new Map<String, Object>{
                'fileName' => 'cab_invoice',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('fake-cab-bill')),
                'extension' => 'pdf',
                'fileType' => 'Bill'
            };
            Map<String, Object> line = new Map<String, Object>{
                'expenseType' => 'Roadways',
                'amount' => 450,
                'startDate' => String.valueOf(Date.today()),
                'endDate' => null,
                'vehicleType' => 'OLA/UBER',
                'files' => new List<Object>{ file }
            };
            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Airport transfer by cab',
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today()),
                'city' => 'Delhi',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ line }
            };

            Test.startTest();
            String expenseName = NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, expenseName);
            Expense_Line__c savedLine = [
                SELECT Expense_Type__c, Amount__c, Vehicle_Type__c, Start_Date__c, End_Date__c, Bill_Attached__c
                FROM Expense_Line__c
                WHERE Expense__r.Employee__c = :u.Id AND Expense_Type__c = 'Roadways'
                LIMIT 1
            ];
            System.assertEquals(450, savedLine.Amount__c);
            System.assertEquals('OLA/UBER', savedLine.Vehicle_Type__c);
            System.assertEquals(Date.today(), savedLine.Start_Date__c);
            System.assertEquals(null, savedLine.End_Date__c);
            System.assertEquals(true, savedLine.Bill_Attached__c);
        }
    }

    @isTest
    static void testSaveExpenseData_OldMonth_ValidationError() {
        User u = getTestUser();
        System.runAs(u) {
            // Travel End Date is 3 months ago
            Date oldDate = Date.today().addMonths(-3);
            Map<String, Object> line = new Map<String, Object>{
                'expenseType' => 'Fooding',
                'amount' => 200,
                'startDate' => String.valueOf(oldDate),
                'endDate' => null,
                'files' => null
            };
            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Old Travel Claim',
                'startDate' => String.valueOf(oldDate),
                'endDate' => String.valueOf(oldDate),
                'city' => 'Delhi',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ line }
            };

            Boolean threw = false;
            Test.startTest();
            try {
                NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            } catch (AuraHandledException e) {
                threw = true;
                System.assert(e.getMessage().contains('submitted up to the 5th'), e.getMessage());
            }
            Test.stopTest();
            System.assert(threw, 'Should throw validation exception for older travel dates');
        }
    }

    @isTest
    static void testSaveExpenseData_PrivateVehicleTypeMapping() {
        User u = getTestUser();
        System.runAs(u) {
            Map<String, Object> line = new Map<String, Object>{
                'expenseType' => 'Private Vehicle',
                'amount' => 500,
                'startDate' => String.valueOf(Date.today()),
                'endDate' => null,
                'vehicleType' => '2-Wheeler',
                'distanceKm' => 125,
                'files' => null
            };
            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Private vehicle test mapping',
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today()),
                'city' => 'Delhi',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ line }
            };

            Test.startTest();
            String expenseName = NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, expenseName);
            Expense_Line__c savedLine = [
                SELECT Expense_Type__c, Amount__c, Vehicle_Type__c, Distance_KM__c
                FROM Expense_Line__c
                WHERE Expense__r.Employee__c = :u.Id AND Expense_Type__c = 'Own Vehicle'
                LIMIT 1
            ];
            System.assertEquals('Own Vehicle', savedLine.Expense_Type__c);
            System.assertEquals(500, savedLine.Amount__c);
        }
    }

    @isTest
    static void testGetPrivateVehicleExpenseLines() {
        User u = getTestUser();
        System.runAs(u) {
            Expense__c exp = new Expense__c(
                Subject__c = 'Market Visit 2-Wheeler',
                Status__c = 'New',
                Is_Private_Vehicle_Expense__c = true,
                Employee__c = u.Id
            );
            insert exp;

            Expense_Line__c line1 = new Expense_Line__c(
                Expense__c = exp.Id,
                Date__c = Date.today(),
                AI_Extracted_Distance__c = 15.5,
                Manually_Extracted_Distance__c = 16.0,
                Vehicle_Type__c = '2-Wheeler',
                Amount__c = 62.0,
                Is_Private_Vehicle_Expense__c = true
            );
            Expense_Line__c line2 = new Expense_Line__c(
                Expense__c = exp.Id,
                Date__c = Date.today().addDays(10),
                AI_Extracted_Distance__c = 10.0,
                Manually_Extracted_Distance__c = 10.0,
                Vehicle_Type__c = '2-Wheeler',
                Amount__c = 40.0,
                Is_Private_Vehicle_Expense__c = true
            );
            insert new List<Expense_Line__c>{ line1, line2 };

            Test.startTest();
            List<Expense_Line__c> emptyRes = NewExpenseFormController.getPrivateVehicleExpenseLines(null, null);
            List<Expense_Line__c> result = NewExpenseFormController.getPrivateVehicleExpenseLines(Date.today().addDays(-2), Date.today().addDays(2));
            Test.stopTest();

            System.assertEquals(0, emptyRes.size());
            System.assertEquals(1, result.size());
            System.assertEquals(line1.Id, result[0].Id);
            System.assertEquals(15.5, result[0].AI_Extracted_Distance__c);
        }
    }

    @isTest
    static void testSaveExpenseData_WithPrivateVehicleLines() {
        User u = getTestUser();
        System.runAs(u) {
            Expense__c exp1 = new Expense__c(
                Subject__c = 'Market Visit Auto Gen 1',
                Status__c = 'New',
                Is_Private_Vehicle_Expense__c = true,
                Employee__c = u.Id
            );
            Expense__c exp2 = new Expense__c(
                Subject__c = 'Market Visit Auto Gen 2',
                Status__c = 'New',
                Is_Private_Vehicle_Expense__c = true,
                Employee__c = u.Id
            );
            insert new List<Expense__c>{ exp1, exp2 };

            Expense_Line__c line1 = new Expense_Line__c(
                Expense__c = exp1.Id,
                Date__c = Date.today(),
                AI_Extracted_Distance__c = 20.0,
                Manually_Extracted_Distance__c = 20.0,
                Vehicle_Type__c = '2-Wheeler',
                Amount__c = 80.0,
                Is_Private_Vehicle_Expense__c = true
            );
            Expense_Line__c line2 = new Expense_Line__c(
                Expense__c = exp2.Id,
                Date__c = Date.today(),
                AI_Extracted_Distance__c = 10.0,
                Manually_Extracted_Distance__c = 10.0,
                Vehicle_Type__c = '4-Wheeler',
                Amount__c = 80.0,
                Is_Private_Vehicle_Expense__c = true
            );
            Expense_Line__c line3 = new Expense_Line__c(
                Expense__c = exp2.Id,
                Date__c = Date.today(),
                AI_Extracted_Distance__c = 5.0,
                Manually_Extracted_Distance__c = 5.0,
                Vehicle_Type__c = '4-Wheeler',
                Amount__c = 40.0,
                Is_Private_Vehicle_Expense__c = true
            );
            insert new List<Expense_Line__c>{ line1, line2, line3 };

            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Consolidated Travel Expense with PV',
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today()),
                'city' => 'Delhi',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>(),
                'privateVehicleLineIds' => new List<Object>{ line1.Id, line2.Id }
            };

            Test.startTest();
            String resultExpName = NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, resultExpName);

            List<Expense__c> exp1Remaining = [SELECT Id FROM Expense__c WHERE Id = :exp1.Id];
            System.assertEquals(0, exp1Remaining.size(), 'Orphaned old Expense__c should be deleted');

            List<Expense__c> exp2Remaining = [
                SELECT Id, (SELECT Id FROM Expense_Lines__r) FROM Expense__c WHERE Id = :exp2.Id
            ];
            System.assertEquals(1, exp2Remaining.size(), 'Expense__c with remaining lines should not be deleted');
            System.assertEquals(1, exp2Remaining[0].Expense_Lines__r.size());
            System.assertEquals(line3.Id, exp2Remaining[0].Expense_Lines__r[0].Id);
        }
    }

    @isTest
    static void testSaveExpenseData_WithStagedDocument() {
        User u = getTestUser();
        System.runAs(u) {
            // Stage a file on user record as lightning-file-upload does
            ContentVersion cv = new ContentVersion(
                Title = 'staged_flight_ticket',
                PathOnClient = 'staged_flight_ticket.pdf',
                VersionData = Blob.valueOf('staged-flight-data'),
                FirstPublishLocationId = u.Id
            );
            insert cv;

            ContentVersion insertedCv = [
                SELECT Id, ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ];

            Map<String, Object> file = new Map<String, Object>{
                'fileName' => 'staged_flight_ticket.pdf',
                'documentId' => insertedCv.ContentDocumentId,
                'fileType' => 'Bill'
            };
            Map<String, Object> line = new Map<String, Object>{
                'expenseType' => 'Air',
                'amount' => 4500,
                'startDate' => String.valueOf(Date.today()),
                'endDate' => null,
                'travelClass' => 'Economy',
                'files' => new List<Object>{ file }
            };
            Map<String, Object> payload = new Map<String, Object>{
                'subject' => 'Flight travel to Bangalore',
                'startDate' => String.valueOf(Date.today()),
                'endDate' => String.valueOf(Date.today()),
                'city' => 'Bangalore',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ line }
            };

            Test.startTest();
            String expenseName = NewExpenseFormController.saveExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, expenseName);
            Expense_Line__c savedLine = [
                SELECT Id, Expense_Type__c, Amount__c, Travel_Class__c, Bill_Attached__c
                FROM Expense_Line__c
                WHERE Expense__r.Employee__c = :u.Id AND Expense_Type__c = 'Air'
                LIMIT 1
            ];
            System.assertEquals(true, savedLine.Bill_Attached__c);

            List<ContentDocumentLink> links = [
                SELECT Id, ContentDocumentId, LinkedEntityId 
                FROM ContentDocumentLink 
                WHERE ContentDocumentId = :insertedCv.ContentDocumentId 
                  AND LinkedEntityId = :savedLine.Id
            ];
            System.assertEquals(1, links.size(), 'Document should be linked to Expense_Line__c');
        }
    }

    @isTest
    static void testDiscardFile() {
        User u = getTestUser();
        System.runAs(u) {
            ContentVersion cv = new ContentVersion(
                Title = 'file_to_discard',
                PathOnClient = 'file_to_discard.pdf',
                VersionData = Blob.valueOf('discard-test-data'),
                FirstPublishLocationId = u.Id
            );
            insert cv;

            ContentVersion insertedCv = [
                SELECT Id, ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ];

            Test.startTest();
            NewExpenseFormController.discardFile(insertedCv.ContentDocumentId);
            NewExpenseFormController.discardFile(null); // Should not throw
            Test.stopTest();

            List<ContentDocument> docs = [
                SELECT Id FROM ContentDocument WHERE Id = :insertedCv.ContentDocumentId
            ];
            System.assertEquals(0, docs.size(), 'ContentDocument should be deleted');
        }
    }

    @isTest
    static void testGetMyExpenseIdByName() {
        User u = getTestUser();
        System.runAs(u) {
            Expense__c exp = new Expense__c(Subject__c = 'Lookup trip', Status__c = 'Pending HOD Approval', Employee__c = u.Id);
            insert exp;
            String expName = [SELECT Name FROM Expense__c WHERE Id = :exp.Id].Name;

            Test.startTest();
            Id foundId = NewExpenseFormController.getMyExpenseIdByName(expName);
            Id blankId = NewExpenseFormController.getMyExpenseIdByName('');
            Id missingId = NewExpenseFormController.getMyExpenseIdByName('NO-SUCH-EXPENSE');
            Test.stopTest();

            System.assertEquals(exp.Id, foundId);
            System.assertEquals(null, blankId);
            System.assertEquals(null, missingId);
        }
    }

    // ===== EDIT MODE (rejected expense resubmission) =====

    private static Id createFileOn(Id linkedEntityId, String title, String fileType) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf(title),
            FirstPublishLocationId = linkedEntityId,
            Description = fileType
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    @isTest
    static void testGetExpenseForEdit_Success() {
        User u = getTestUser();
        System.runAs(u) {
            Expense__c exp = new Expense__c(
                Subject__c = 'Rejected trip',
                Status__c = 'Rejected by HOD',
                Employee__c = u.Id,
                Remark__c = 'Please attach proof',
                Travel_Start_Date__c = Date.today(),
                Travel_End_Date__c = Date.today()
            );
            insert exp;

            Expense_Line__c airLine = new Expense_Line__c(
                Expense__c = exp.Id, Expense_Type__c = 'Air', Amount__c = 5000,
                Start_Date__c = Date.today(), Travel_Class__c = 'Business', City__c = 'Delhi'
            );
            Expense_Line__c pvLine = new Expense_Line__c(
                Expense__c = exp.Id, Expense_Type__c = 'Own Vehicle', Amount__c = 80,
                Date__c = Date.today(), Vehicle_Type__c = '2-Wheeler', Is_Private_Vehicle_Expense__c = true
            );
            insert new List<Expense_Line__c>{ airLine, pvLine };
            createFileOn(airLine.Id, 'air_ticket', 'Bill');
            createFileOn(airLine.Id, 'approval_mail', 'Proof');
            createFileOn(airLine.Id, 'legacy_file', null);

            Test.startTest();
            NewExpenseFormController.ExpenseEditData data = NewExpenseFormController.getExpenseForEdit(exp.Id);
            Test.stopTest();

            System.assertEquals('Please attach proof', data.expense.Remark__c);
            System.assertEquals(2, data.lines.size());
            for (NewExpenseFormController.ExpenseEditLine editLine : data.lines) {
                if (editLine.line.Id == pvLine.Id) {
                    System.assertEquals(true, editLine.isPrivateVehicle);
                } else {
                    System.assertEquals(false, editLine.isPrivateVehicle);
                    System.assertEquals(3, editLine.files.size());
                    Integer bills = 0;
                    Integer proofs = 0;
                    for (NewExpenseFormController.ExpenseEditFile f : editLine.files) {
                        if (f.fileType == 'Proof') {
                            proofs++;
                        } else {
                            bills++;
                        }
                    }
                    System.assertEquals(1, proofs, 'Tagged proof should load as Proof');
                    System.assertEquals(2, bills, 'Bill and untagged legacy file should load as Bill');
                }
            }
        }
    }

    @isTest
    static void testGetExpenseForEdit_KeepsEntryOrderAndJustification() {
        User u = getTestUser();
        System.runAs(u) {
            Expense__c exp = new Expense__c(Subject__c = 'Overlap trip', Status__c = 'Rejected by HOD', Employee__c = u.Id);
            insert exp;

            Date day1 = Date.today();
            // Inserted in one DML (same CreatedDate), like saveExpenseData does
            List<Expense_Line__c> lodgingLines = new List<Expense_Line__c>{
                new Expense_Line__c(Expense__c = exp.Id, Expense_Type__c = 'Lodging', Amount__c = 1000,
                    Start_Date__c = day1, End_Date__c = day1.addDays(2)),
                new Expense_Line__c(Expense__c = exp.Id, Expense_Type__c = 'Lodging', Amount__c = 1000,
                    Start_Date__c = day1.addDays(1), End_Date__c = day1.addDays(3),
                    Justification__c = 'Shifted hotel mid-stay')
            };
            insert lodgingLines;

            Test.startTest();
            NewExpenseFormController.ExpenseEditData data = NewExpenseFormController.getExpenseForEdit(exp.Id);
            Test.stopTest();

            System.assertEquals(2, data.lines.size());
            System.assertEquals(lodgingLines[0].Id, data.lines[0].line.Id, 'Lines must come back in entry order');
            System.assertEquals(lodgingLines[1].Id, data.lines[1].line.Id, 'Lines must come back in entry order');
            System.assertEquals('Shifted hotel mid-stay', data.lines[1].line.Justification__c);
        }
    }

    @isTest
    static void testGetExpenseForEdit_NotRejected() {
        User u = getTestUser();
        System.runAs(u) {
            Expense__c exp = new Expense__c(Subject__c = 'Pending trip', Status__c = 'Pending HOD Approval', Employee__c = u.Id);
            insert exp;

            Boolean threw = false;
            Test.startTest();
            try {
                NewExpenseFormController.getExpenseForEdit(exp.Id);
            } catch (AuraHandledException e) {
                threw = true;
                System.assertEquals(NewExpenseFormController.EDIT_NOT_ALLOWED_MSG, e.getMessage());
            }
            Test.stopTest();
            System.assert(threw, 'Non-rejected expense must not be editable');
        }
    }

    @isTest
    static void testResubmitExpenseData_NotOwner() {
        User u = getTestUser();
        Expense__c exp = new Expense__c(Subject__c = 'Other user trip', Status__c = 'Rejected by HOD', Employee__c = UserInfo.getUserId());
        insert exp;

        System.runAs(u) {
            Boolean threw = false;
            Test.startTest();
            try {
                NewExpenseFormController.resubmitExpenseData(JSON.serialize(new Map<String, Object>{
                    'expenseId' => exp.Id,
                    'subject' => 'Hijack',
                    'lines' => new List<Object>()
                }));
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assert(threw, 'Another user\'s expense must not be resubmittable');
        }
    }

    @isTest
    static void testResubmitExpenseData_Success() {
        User u = getTestUser();
        System.runAs(u) {
            Date travelDay = Date.today();
            Expense__c exp = new Expense__c(
                Subject__c = 'Rejected trip',
                Status__c = 'Rejected by HR',
                Employee__c = u.Id,
                Remark__c = 'Amount too high',
                Travel_Start_Date__c = travelDay,
                Travel_End_Date__c = travelDay
            );
            insert exp;

            Expense_Line__c airLine = new Expense_Line__c(
                Expense__c = exp.Id, Expense_Type__c = 'Air', Amount__c = 9000, Approved_Amount__c = 9000,
                Start_Date__c = travelDay, Travel_Class__c = 'Economy', City__c = 'Delhi', City_Tier__c = 'Tier 1'
            );
            Expense_Line__c foodLine = new Expense_Line__c(
                Expense__c = exp.Id, Expense_Type__c = 'Fooding', Amount__c = 400,
                Start_Date__c = travelDay, City__c = 'Delhi', City_Tier__c = 'Tier 1'
            );
            Expense_Line__c pvKept = new Expense_Line__c(
                Expense__c = exp.Id, Expense_Type__c = 'Own Vehicle', Amount__c = 80, Approved_Amount__c = 0,
                Date__c = travelDay, Vehicle_Type__c = '2-Wheeler', Is_Private_Vehicle_Expense__c = true
            );
            Expense_Line__c pvUnticked = new Expense_Line__c(
                Expense__c = exp.Id, Expense_Type__c = 'Own Vehicle', Amount__c = 40,
                Date__c = travelDay, Vehicle_Type__c = '2-Wheeler', Is_Private_Vehicle_Expense__c = true
            );
            insert new List<Expense_Line__c>{ airLine, foodLine, pvKept, pvUnticked };

            Id keptAirDoc = createFileOn(airLine.Id, 'air_ticket', 'Bill');
            Id removedAirDoc = createFileOn(airLine.Id, 'old_ticket', 'Bill');
            Id foodDoc = createFileOn(foodLine.Id, 'food_bill', 'Bill');
            Id stagedDoc = createFileOn(u.Id, 'hotel_bill', null);

            Map<String, Object> editedAir = new Map<String, Object>{
                'lineId' => airLine.Id,
                'expenseType' => 'Air',
                'amount' => 6000,
                'startDate' => String.valueOf(travelDay),
                'travelClass' => 'Economy',
                'files' => new List<Object>{
                    new Map<String, Object>{ 'documentId' => keptAirDoc, 'fileName' => 'air_ticket.pdf', 'fileType' => 'Bill', 'isExisting' => true }
                }
            };
            Map<String, Object> newLodging = new Map<String, Object>{
                'expenseType' => 'Lodging',
                'amount' => 2500,
                'startDate' => String.valueOf(travelDay),
                'endDate' => String.valueOf(travelDay),
                'files' => new List<Object>{
                    new Map<String, Object>{ 'documentId' => stagedDoc, 'fileName' => 'hotel_bill.pdf', 'fileType' => 'Bill' }
                }
            };
            Map<String, Object> payload = new Map<String, Object>{
                'expenseId' => exp.Id,
                'subject' => 'Rejected trip - corrected',
                'startDate' => String.valueOf(travelDay),
                'endDate' => String.valueOf(travelDay),
                'city' => 'Delhi',
                'cityTier' => 'Tier 1',
                'lines' => new List<Object>{ editedAir, newLodging },
                'privateVehicleLineIds' => new List<Object>{ pvKept.Id },
                'removedLineIds' => new List<Object>{ foodLine.Id },
                'removedDocumentIds' => new List<Object>{ removedAirDoc, foodDoc }
            };

            Test.startTest();
            String expName = NewExpenseFormController.resubmitExpenseData(JSON.serialize(payload));
            Test.stopTest();

            System.assertNotEquals(null, expName);

            Expense__c savedExp = [SELECT Status__c, Subject__c, Remark__c, Submitted_Date__c FROM Expense__c WHERE Id = :exp.Id];
            System.assertEquals('Pending HOD Approval', savedExp.Status__c);
            System.assertEquals('Rejected trip - corrected', savedExp.Subject__c);
            System.assertEquals('Amount too high', savedExp.Remark__c, 'Remark should be kept');
            System.assertEquals(Date.today(), savedExp.Submitted_Date__c);

            Expense_Line__c savedAir = [SELECT Amount__c, Approved_Amount__c FROM Expense_Line__c WHERE Id = :airLine.Id];
            System.assertEquals(6000, savedAir.Amount__c);
            System.assertEquals(6000, savedAir.Approved_Amount__c);

            System.assertEquals(0, [SELECT COUNT() FROM Expense_Line__c WHERE Id = :foodLine.Id], 'Removed line should be deleted');
            System.assertEquals(0, [SELECT COUNT() FROM ContentDocument WHERE Id IN :new Set<Id>{ removedAirDoc, foodDoc }], 'Removed files should be deleted');
            System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :airLine.Id AND ContentDocumentId = :keptAirDoc], 'Kept file should stay linked once');

            Expense_Line__c lodging = [SELECT Id, Bill_Attached__c FROM Expense_Line__c WHERE Expense__c = :exp.Id AND Expense_Type__c = 'Lodging'];
            System.assertEquals(true, lodging.Bill_Attached__c);
            System.assertEquals(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :lodging.Id AND ContentDocumentId = :stagedDoc]);
            System.assertEquals('Bill', [SELECT Description FROM ContentVersion WHERE ContentDocumentId = :stagedDoc AND IsLatest = true].Description, 'New file should be tagged');

            Expense_Line__c savedPvKept = [SELECT Expense__c, Approved_Amount__c FROM Expense_Line__c WHERE Id = :pvKept.Id];
            System.assertEquals(exp.Id, savedPvKept.Expense__c);
            System.assertEquals(80, savedPvKept.Approved_Amount__c);

            Expense_Line__c savedPvUnticked = [SELECT Expense__c, Expense__r.Status__c, Expense__r.Is_Private_Vehicle_Expense__c FROM Expense_Line__c WHERE Id = :pvUnticked.Id];
            System.assertNotEquals(exp.Id, savedPvUnticked.Expense__c, 'Unticked PV line should leave the resubmitted expense');
            System.assertEquals('New', savedPvUnticked.Expense__r.Status__c);
            System.assertEquals(true, savedPvUnticked.Expense__r.Is_Private_Vehicle_Expense__c);
        }
    }
}