@isTest
private class TenderDepartmentControllerTest {

    // ============================================================
    //
    // 'Steel Pipes' and 'Railway Electrification Structure' are used
    // below because they are both confirmed active picklist values AND
    // correspond to real departments with active Utkarsh Sales /
    // Utkarsh Tender profile users in this org.
    // ============================================================

    private static final String DEPARTMENT_1 = 'Steel Pipes';
    private static final String DEPARTMENT_2 = 'Railway Electrification Structure';

    // ============================================================
    // TEST DATA
    // ============================================================

    @TestSetup
    static void setup() {

        List<Profile> profiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Utkarsh Sales' WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assert(
            !profiles.isEmpty(),
            'Profile "Utkarsh Sales" must exist for this test to run.'
        );

        Profile p = profiles[0];

        String uniqueValue = String.valueOf(DateTime.now().getTime());

        // --------------------------------------------------------
        // Tender User
        // --------------------------------------------------------
        User tenderUser = new User(
            FirstName         = 'Test',
            LastName          = 'TenderUser',
            Alias             = 'ttu',
            Email             = 'tender.user.' + uniqueValue + '@example.com',
            Username          = 'tender.user.' + uniqueValue + '@example.com',
            ProfileId         = p.Id,
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department        = 'Finance; Procurement/Legal',
            Tender_Access_User__c = true,
            IsActive          = true
        );

        Database.insert(tenderUser, AccessLevel.SYSTEM_MODE);


        // --------------------------------------------------------
        // Non Tender User
        // --------------------------------------------------------
        User nonTenderUser = new User(
            FirstName         = 'Test',
            LastName          = 'NonTenderUser',
            Alias             = 'tntu',
            Email             = 'nontender.user.' + uniqueValue + '@example.com',
            Username          = 'nontender.user.' + uniqueValue + '@example.com',
            ProfileId         = p.Id,
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department        = 'Finance',
            Tender_Access_User__c = false,
            IsActive          = true
        );

        Database.insert(nonTenderUser, AccessLevel.SYSTEM_MODE);


        // --------------------------------------------------------
        // Tender User with blank Department
        // Covers String.isBlank(u.Department)
        // --------------------------------------------------------
        User blankDepartmentUser = new User(
            FirstName         = 'Test',
            LastName          = 'BlankDepartmentUser',
            Alias             = 'bdu',
            Email             = 'blank.department.' + uniqueValue + '@example.com',
            Username          = 'blank.department.' + uniqueValue + '@example.com',
            ProfileId         = p.Id,
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department        = null,
            Tender_Access_User__c = true,
            IsActive          = true
        );

        Database.insert(blankDepartmentUser, AccessLevel.SYSTEM_MODE);


        // --------------------------------------------------------
        // Main Tender - uses a fixed, known-good department
        // --------------------------------------------------------
        Tender__c tender = new Tender__c(
            Department_Name__c = DEPARTMENT_1
        );

        Database.insert(tender, AccessLevel.SYSTEM_MODE);


        // --------------------------------------------------------
        // Related Bidder
        // --------------------------------------------------------
        Bidders__c bidder = new Bidders__c(
            Name = 'Test Bidder',
            Tender__c = tender.Id
        );

        Database.insert(bidder, AccessLevel.SYSTEM_MODE);


        // --------------------------------------------------------
        // Related Bidder Contact
        // --------------------------------------------------------
        Bidders_Contact_Details__c contact =
            new Bidders_Contact_Details__c(
                Name = 'Test Bidder Contact',
                Tender__c = tender.Id
            );

        Database.insert(contact, AccessLevel.SYSTEM_MODE);


        // --------------------------------------------------------
        // Related AI Summary
        // --------------------------------------------------------
        Tender_Ai_Summary_Json__c summary =
            new Tender_Ai_Summary_Json__c(
                Tender__c = tender.Id
            );

        Database.insert(summary, AccessLevel.SYSTEM_MODE);


        // --------------------------------------------------------
        // Related Document
        // --------------------------------------------------------
        Tender_Docoment_Details__c document =
            new Tender_Docoment_Details__c(
                Tender__c = tender.Id
            );

        Database.insert(document, AccessLevel.SYSTEM_MODE);
    }


    // ============================================================
    // HELPER - TENDER DEPARTMENT -> USER Departments__c MAPPING
    //
    // Mirrors TenderOwnerValidationHandler.getDepartmentMapping().
    // TenderOwnerValidationHandler validates the Owner's Departments__c
    // (custom multi-select picklist) against the Tender's
    // Department_Name__c after passing it through this exact mapping -
    // NOT the standard User.Department field. Both fields are set below
    // so tests covering TenderDepartmentController.getDepartmentUsers()
    // (which reads User.Department) and the trigger validation (which
    // reads User.Departments__c) both work correctly.
    // ============================================================

    private static Map<String, String> getUserDepartmentMapping() {

        return new Map<String, String>{
            'HIGH MAST & POLYGONAL'             => 'High_Mast_Department',
            'CRASH BARRIER'                     => 'Crash_Barrier_Department',
            'HDPE'                               => 'HDPE_Pipe_Department',
            'STEEL TUBULAR POLES'               => 'Steel_Tubular_Pole_Department',
            'POLYMER'                            => 'PVC',
            'TRANSMISSION & TELECOM TOWER'      => 'Transmission_Tower_Department',
            'PRE ENGINEERING BUILDING'          => 'PEB',
            'SOLAR STRUCTURE'                   => 'Solar_Structure_Department',
            'RAILWAY ELECTRIFICATION STRUCTURE' => 'Core_Department',
            'STEEL PIPES'                        => 'Steel_Pipes_Department'
        };
    }

// helper create tender user

    private static User createTenderUser(
        String department
    ) {

       
        List<Profile> profiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Utkarsh Tender' WITH SYSTEM_MODE
            LIMIT 1
        ];

        System.assert(
            !profiles.isEmpty(),
            'Profile "Utkarsh Tender" must exist for this test to run.'
        );

        Id profileId = profiles[0].Id;

        String uniqueValue =
            String.valueOf(DateTime.now().getTime());

        String mappedDepartment =
            getUserDepartmentMapping().get(
                department.trim().toUpperCase()
            );

        System.assertNotEquals(
            null,
            mappedDepartment,
            'No Departments__c mapping found for Tender department: ' + department
        );

        User u = new User(
            FirstName         = 'New',
            LastName          = 'DepartmentOwner',
            Alias             = 'ndow',
            Email             = 'new.owner.' +
                                uniqueValue +
                                '@example.com',
            Username          = 'new.owner.' +
                                uniqueValue +
                                '@example.com',
            ProfileId         = profileId,
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department        = department,
            Departments__c    = mappedDepartment,
            Tender_Access_User__c = true,
            IsActive          = true
        );

        // Isolate the setup-object (User) DML into its own transaction
        // so it cannot collide with the non-setup object DML performed
        // later in the calling test method.
        // Uses SYSTEM_MODE because Departments__c / Tender_Access_User__c
        // FLS on User is not guaranteed for every running/deploying user
        // (metadata deployments do not auto-grant FLS) - this is test
        // setup data, not a real security-sensitive operation.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Database.insert(u, AccessLevel.SYSTEM_MODE);
        }

        return u;
    }


    // ============================================================
    // getTenderDetails - SUCCESS
    // ============================================================

    @isTest
    static void testGetTenderDetails_Success() {

        Tender__c tender = [
            SELECT
                Id,
                Department_Name__c,
                OwnerId
            FROM Tender__c WITH SYSTEM_MODE
            LIMIT 1
        ];

        Test.startTest();

        TenderDepartmentController.TenderInfo info =
            TenderDepartmentController.getTenderDetails(
                tender.Id
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            info
        );

        System.assertEquals(
            tender.Department_Name__c,
            info.department
        );

        System.assertEquals(
            tender.OwnerId,
            info.ownerId
        );
    }


    // ============================================================
    // getTenderDetails - NULL ID
    // ============================================================

    @isTest
    static void testGetTenderDetails_NullId() {

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TenderDepartmentController.getTenderDetails(null);

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(
            exceptionThrown,
            'Expected exception for null Tender Id.'
        );
    }


    // ============================================================
    // getDepartments
    // ============================================================

    @isTest
    static void testGetDepartments() {

        Test.startTest();

        List<TenderDepartmentController.PicklistOption>
            options =
            TenderDepartmentController.getDepartments();

        Test.stopTest();

        System.assertNotEquals(
            null,
            options
        );

        System.assert(
            options.size() > 0,
            'At least one department should be returned.'
        );

        for (
            TenderDepartmentController.PicklistOption option :
            options
        ) {

            System.assertNotEquals(
                'Enquiry',
                option.value,
                'Enquiry must be excluded.'
            );

            System.assertNotEquals(
                null,
                option.label
            );

            System.assertNotEquals(
                null,
                option.value
            );
        }
    }


    // ============================================================
    // getDepartmentUsers - BLANK
    // ============================================================

    @isTest
    static void testGetDepartmentUsers_Blank() {

        Test.startTest();

        List<TenderDepartmentController.UserOption>
            result =
            TenderDepartmentController.getDepartmentUsers('');

        Test.stopTest();

        System.assertEquals(
            0,
            result.size()
        );
    }


    // ============================================================
    // getDepartmentUsers - NULL
    // ============================================================

    @isTest
    static void testGetDepartmentUsers_Null() {

        Test.startTest();

        List<TenderDepartmentController.UserOption>
            result =
            TenderDepartmentController.getDepartmentUsers(null);

        Test.stopTest();

        System.assertEquals(
            0,
            result.size()
        );
    }


    // ============================================================
    // getDepartmentUsers - FINANCE
    // ============================================================

    @isTest
    static void testGetDepartmentUsers_Finance() {

        Test.startTest();

        List<TenderDepartmentController.UserOption>
            result =
            TenderDepartmentController.getDepartmentUsers(
                'Finance'
            );

        Test.stopTest();

        System.assertEquals(
            1,
            result.size(),
            'Finance should return the Tender User.'
        );

        System.assertEquals(
            'Test TenderUser',
            result[0].label
        );

        System.assertNotEquals(
            null,
            result[0].value
        );

        System.assert(
            result[0].department.contains('Finance')
        );
    }


    // ============================================================
    // getDepartmentUsers - LEGAL
    // ============================================================

    @isTest
    static void testGetDepartmentUsers_Legal() {

        Test.startTest();

        List<TenderDepartmentController.UserOption>
            result =
            TenderDepartmentController.getDepartmentUsers(
                'legal'
            );

        Test.stopTest();

        System.assertEquals(
            1,
            result.size(),
            'Legal should match Procurement/Legal.'
        );

        System.assertEquals(
            'Test TenderUser',
            result[0].label
        );
    }


    // ============================================================
    // getDepartmentUsers - NO MATCH
    // ============================================================

    @isTest
    static void testGetDepartmentUsers_NoMatch() {

        Test.startTest();

        List<TenderDepartmentController.UserOption>
            result =
            TenderDepartmentController.getDepartmentUsers(
                'Marketing'
            );

        Test.stopTest();

        System.assertEquals(
            0,
            result.size()
        );
    }


    // ============================================================
    // updateDepartmentAndOwner
    // NULL TENDER ID
    // ============================================================

    @isTest
    static void testUpdateDepartmentAndOwner_NullTenderId() {

        User owner = [
            SELECT Id
            FROM User
            WHERE LastName = 'TenderUser' WITH SYSTEM_MODE
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TenderDepartmentController.updateDepartmentAndOwner(
                null,
                'Finance',
                owner.Id
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(
            exceptionThrown,
            'Expected exception for null Tender Id.'
        );
    }


    // ============================================================
    // updateDepartmentAndOwner
    // BLANK DEPARTMENT
    // ============================================================

    @isTest
    static void testUpdateDepartmentAndOwner_BlankDepartment() {

        Tender__c tender = [
            SELECT Id
            FROM Tender__c WITH SYSTEM_MODE
            LIMIT 1
        ];

        User owner = [
            SELECT Id
            FROM User
            WHERE LastName = 'TenderUser' WITH SYSTEM_MODE
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TenderDepartmentController.updateDepartmentAndOwner(
                tender.Id,
                '',
                owner.Id
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(
            exceptionThrown,
            'Expected exception for blank Department.'
        );
    }


    // ============================================================
    // updateDepartmentAndOwner
    // NULL OWNER
    // ============================================================

    @isTest
    static void testUpdateDepartmentAndOwner_NullOwnerId() {

        Tender__c tender = [
            SELECT
                Id,
                Department_Name__c
            FROM Tender__c WITH SYSTEM_MODE
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TenderDepartmentController.updateDepartmentAndOwner(
                tender.Id,
                tender.Department_Name__c,
                null
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(
            exceptionThrown,
            'Expected exception for null Owner Id.'
        );
    }


    // ============================================================
    // SUCCESS + ALL RELATED RECORDS
    // ============================================================

    @isTest
    static void testUpdateDepartmentAndOwner_Success() {

        Tender__c tender = [
            SELECT
                Id,
                Department_Name__c,
                OwnerId
            FROM Tender__c WITH SYSTEM_MODE
            LIMIT 1
        ];

       
        String newDepartment = DEPARTMENT_2;

        User newOwner =
            createTenderUser(newDepartment);

        Test.startTest();

        TenderDepartmentController.updateDepartmentAndOwner(
            tender.Id,
            newDepartment,
            newOwner.Id
        );

        Test.stopTest();


        // --------------------------------------------------------
        // Verify Tender
        // --------------------------------------------------------

        Tender__c updatedTender = [
            SELECT
                Id,
                Department_Name__c,
                OwnerId
            FROM Tender__c 
            WHERE Id = :tender.Id WITH SYSTEM_MODE
        ];

        System.assertEquals(
            newDepartment,
            updatedTender.Department_Name__c
        );

        System.assertEquals(
            newOwner.Id,
            updatedTender.OwnerId
        );


        // --------------------------------------------------------
        // Verify Bidders
        // --------------------------------------------------------

        List<Bidders__c> bidders = [
            SELECT
                Id,
                OwnerId
            FROM Bidders__c
            WHERE Tender__c = :tender.Id WITH SYSTEM_MODE
        ];

        System.assertEquals(
            1,
            bidders.size()
        );

        for (Bidders__c bidder : bidders) {

            System.assertEquals(
                newOwner.Id,
                bidder.OwnerId
            );
        }


        // --------------------------------------------------------
        // Verify Contacts
        // --------------------------------------------------------

        List<Bidders_Contact_Details__c> contacts = [
            SELECT
                Id,
                OwnerId
            FROM Bidders_Contact_Details__c 
            WHERE Tender__c = :tender.Id WITH SYSTEM_MODE
        ];

        System.assertEquals(
            1,
            contacts.size()
        );

        for (
            Bidders_Contact_Details__c contact :
            contacts
        ) {

            System.assertEquals(
                newOwner.Id,
                contact.OwnerId
            );
        }


        // --------------------------------------------------------
        // Verify AI Summary
        // --------------------------------------------------------

        List<Tender_Ai_Summary_Json__c> summaries = [
            SELECT
                Id,
                OwnerId
            FROM Tender_Ai_Summary_Json__c
            WHERE Tender__c = :tender.Id WITH SYSTEM_MODE
        ];

        System.assertEquals(
            1,
            summaries.size()
        );

        for (
            Tender_Ai_Summary_Json__c summary :
            summaries
        ) {

            System.assertEquals(
                newOwner.Id,
                summary.OwnerId
            );
        }


        // --------------------------------------------------------
        // Verify Documents
        // --------------------------------------------------------

        List<Tender_Docoment_Details__c> documents = [
            SELECT
                Id,
                OwnerId
            FROM Tender_Docoment_Details__c
            WHERE Tender__c = :tender.Id WITH SYSTEM_MODE
        ];

        System.assertEquals(
            1,
            documents.size()
        );

        for (
            Tender_Docoment_Details__c document :
            documents
        ) {

            System.assertEquals(
                newOwner.Id,
                document.OwnerId
            );
        }
    }


    // ============================================================
    // SUCCESS - NO RELATED RECORDS
    // ============================================================

    @isTest
    static void testUpdateDepartmentAndOwner_NoRelatedRecords() {

        // owner reassignment on a record with no child records).
        String department = DEPARTMENT_1;

        Tender__c tenderWithoutChildren =
            new Tender__c(
                Department_Name__c = department
            );

        Database.insert(tenderWithoutChildren, AccessLevel.SYSTEM_MODE);
        

        User newOwner =
            createTenderUser(department);

        Test.startTest();

        TenderDepartmentController.updateDepartmentAndOwner(
            tenderWithoutChildren.Id,
            department,
            newOwner.Id
        );

        Test.stopTest();


        // --------------------------------------------------------
        // Verify Tender
        // --------------------------------------------------------

        Tender__c updated = [
            SELECT
                Id,
                Department_Name__c,
                OwnerId
            FROM Tender__c 
            WHERE Id = :tenderWithoutChildren.Id WITH SYSTEM_MODE
        ];

        System.assertEquals(
            department,
            updated.Department_Name__c
        );

        System.assertEquals(
            newOwner.Id,
            updated.OwnerId
        );


        // --------------------------------------------------------
        // Verify no child records
        // --------------------------------------------------------

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Bidders__c
                WHERE Tender__c = :tenderWithoutChildren.Id
            ]
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Bidders_Contact_Details__c
                WHERE Tender__c = :tenderWithoutChildren.Id
            ]
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Tender_Ai_Summary_Json__c
                WHERE Tender__c = :tenderWithoutChildren.Id
            ]
        );

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Tender_Docoment_Details__c
                WHERE Tender__c = :tenderWithoutChildren.Id
            ]
        );
    }
}