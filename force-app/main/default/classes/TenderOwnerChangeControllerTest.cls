@IsTest
private class TenderOwnerChangeControllerTest {

    // ============================================================
    //
    // Tender__c.Department_Name__c is a RESTRICTED picklist. Confirmed
    // valid, active values are:
    //   High Mast & Polygonal, Steel Pipes, Crash Barrier,
    //   Steel Tubular Poles, Polymer, HDPE,
    //   Transmission & Telecom Tower, Pre Engineering Building,
    //   Railway Electrification Structure, Solar Structure, Enquiry
    //
    // 'Technical' / 'Sales' (used only for the standard User.Department
    // field below, which is unrelated) are NOT valid values here.
    //
    // TenderOwnerValidationHandler (a before-update trigger handler on
    // Tender__c) additionally requires the new Owner's Departments__c
    // (custom multi-select picklist) to contain the MAPPED value of
    // whatever department the Tender is set to - see
    // getUserDepartmentMapping() below, which mirrors
    // TenderOwnerValidationHandler.getDepartmentMapping() exactly.
    // ============================================================

    private static final String TENDER_DEPARTMENT = 'Steel Pipes';

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

    // ============================================================
    // Test Setup
    // ============================================================

    @TestSetup
    static void setupData() {

        // Get the profiles that are now allowed to be Owners
        List<Profile> salesProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Utkarsh Sales'
            LIMIT 1
        ];

        System.assert(
            !salesProfiles.isEmpty(),
            'Profile "Utkarsh Sales" must exist for this test to run.'
        );

        List<Profile> tenderProfiles = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Utkarsh Tender'
            LIMIT 1
        ];

        System.assert(
            !tenderProfiles.isEmpty(),
            'Profile "Utkarsh Tender" must exist for this test to run.'
        );

        Profile salesProfile  = salesProfiles[0];
        Profile tenderProfile = tenderProfiles[0];

        String mappedDepartment =
            getUserDepartmentMapping().get(
                TENDER_DEPARTMENT.trim().toUpperCase()
            );

        String uniqueKey = String.valueOf(DateTime.now().getTime());

        // ------------------------------------------------------------
        // User 1
        // Eligible:
        // Active = true
        // Tender Access = true
        // Profile = Utkarsh Sales
        // Department (standard field, used by getDepartmentUsers) = Technical
        // Departments__c (custom, used by TenderOwnerValidationHandler)
        //   = mapped value for TENDER_DEPARTMENT, so this user can also
        //     be used as a valid Owner in cascade-style tests.
        // ------------------------------------------------------------

        User technicalUser = new User(
            FirstName = 'Technical',
            LastName = 'Owner',
            Alias = 'techown',
            Email = 'technical' + uniqueKey + '@test.com',
            Username = 'technical' + uniqueKey + '@test.com',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department = 'Technical',
            Departments__c = mappedDepartment,
            Tender_Access_User__c = true
        );

        // ------------------------------------------------------------
        // User 2
        // Eligible:
        // Active = true
        // Tender Access = true
        // Profile = Utkarsh Tender
        // Department (standard field) = Sales;Technical;Finance
        // Departments__c (custom) = mapped value for TENDER_DEPARTMENT,
        //   so this user passes TenderOwnerValidationHandler when set
        //   as the new Owner of a Tender in TENDER_DEPARTMENT.
        // ------------------------------------------------------------

        User multiDepartmentUser = new User(
            FirstName = 'Multi',
            LastName = 'Department',
            Alias = 'multidep',
            Email = 'multidep' + uniqueKey + '@test.com',
            Username = 'multidep' + uniqueKey + '@test.com',
            ProfileId = tenderProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department = 'Sales;Technical;Finance',
            Departments__c = mappedDepartment,
            Tender_Access_User__c = true
        );

        // ------------------------------------------------------------
        // User 3
        // Same Department but Tender Access = false
        // Should NOT be returned
        // ------------------------------------------------------------

        User noTenderAccessUser = new User(
            FirstName = 'No',
            LastName = 'TenderAccess',
            Alias = 'notend',
            Email = 'notender' + uniqueKey + '@test.com',
            Username = 'notender' + uniqueKey + '@test.com',
            ProfileId = salesProfile.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department = 'Technical',
            Tender_Access_User__c = false
        );

        // ------------------------------------------------------------
        // User 4
        // Correct Department + Tender Access
        // BUT wrong Profile
        //
        // Use the current user's profile for this negative test.
        // ------------------------------------------------------------

        User differentProfileUser = new User(
            FirstName = 'Different',
            LastName = 'Profile',
            Alias = 'diffprof',
            Email = 'different' + uniqueKey + '@test.com',
            Username = 'different' + uniqueKey + '@test.com',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            Department = 'Technical',
            Tender_Access_User__c = true
        );

    // ------------------------------------------------------------
// Insert Users in SYSTEM MODE
// ------------------------------------------------------------

List<User> users = new List<User>{
    technicalUser,
    multiDepartmentUser,
    noTenderAccessUser,
    differentProfileUser
};

Database.insert(users, AccessLevel.SYSTEM_MODE);
    }


    // ============================================================
    // Helper Method
    // ============================================================

    private static Tender__c createTender(Id ownerId) {

        Tender__c tender = new Tender__c(
            Department_Name__c = TENDER_DEPARTMENT,
            OwnerId = ownerId,
            Tender_Stage__c = 'Open'
        );

        insert tender;

        return tender;
    }


    // ============================================================
    // Test getTenderOwnerDetails()
    // ============================================================

    @IsTest
    static void testGetTenderOwnerDetails() {

        User currentOwner = [
            SELECT Id, Name
            FROM User
            WHERE LastName = 'Owner'
            LIMIT 1
        ];

        Tender__c tender = createTender(currentOwner.Id);

        Test.startTest();

        TenderOwnerChangeController.TenderOwnerInfo result =
            TenderOwnerChangeController.getTenderOwnerDetails(
                tender.Id
            );

        Test.stopTest();

        System.assertNotEquals(
            null,
            result,
            'TenderOwnerInfo should be returned.'
        );

        System.assertEquals(
            tender.Id,
            result.tenderId,
            'Tender Id should match.'
        );

        System.assertEquals(
            tender.Department_Name__c,
            result.department,
            'Department should match the Tender.'
        );

        System.assertEquals(
            currentOwner.Id,
            result.ownerId,
            'Owner Id should match.'
        );

        System.assertEquals(
            currentOwner.Name,
            result.ownerName,
            'Owner name should match.'
        );
    }

    // ============================================================
    // Test getTenderOwnerDetails() - Null Id
    // ============================================================

    @IsTest
    static void testGetTenderOwnerDetailsNullId() {

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TenderOwnerChangeController.getTenderOwnerDetails(null);

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException should be thrown when Tender Id is null.'
        );
    }


    // ============================================================
    // Test getTenderOwnerDetails() - Department Blank
    // ============================================================

    @IsTest
    static void testGetTenderOwnerDetailsBlankDepartment() {

        User owner = [
            SELECT Id
            FROM User
            WHERE LastName = 'Owner'
            LIMIT 1
        ];

        Tender__c tender = new Tender__c(
            OwnerId = owner.Id
        );

        insert tender;

        Test.startTest();

        Boolean exceptionThrown = false;

        try {

            TenderOwnerChangeController.getTenderOwnerDetails(
                tender.Id
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException should be thrown when Tender Department is blank.'
        );
    }


    // ============================================================
    // Test getDepartmentUsers()
    // ============================================================

    @IsTest
    static void testGetDepartmentUsers() {

        Test.startTest();

        List<TenderOwnerChangeController.UserOption> results =
            TenderOwnerChangeController.getDepartmentUsers(
                'Technical'
            );

        Test.stopTest();

        System.assertEquals(
            2,
            results.size(),
            'Only eligible Technical users should be returned.'
        );

        Set<String> returnedNames = new Set<String>();

        for (
            TenderOwnerChangeController.UserOption option :
            results
        ) {
            returnedNames.add(option.label);
        }

        System.assert(
            returnedNames.contains('Technical Owner'),
            'Utkarsh Sales user should be returned.'
        );

        System.assert(
            returnedNames.contains('Multi Department'),
            'Utkarsh Tender user with multiple departments should be returned.'
        );

        System.assert(
            !returnedNames.contains('No TenderAccess'),
            'User without Tender Access should not be returned.'
        );

        System.assert(
            !returnedNames.contains('Different Profile'),
            'User with an invalid Profile should not be returned.'
        );
    }


    // ============================================================
    // Test getDepartmentUsers() - Blank Department
    // ============================================================

    @IsTest
    static void testGetDepartmentUsersBlankDepartment() {

        Test.startTest();

        List<TenderOwnerChangeController.UserOption> results =
            TenderOwnerChangeController.getDepartmentUsers('');

        Test.stopTest();

        System.assertEquals(
            0,
            results.size(),
            'Blank department should return an empty list.'
        );
    }


    // ============================================================
    // Test updateOwner()
    //
    // Also verifies:
    // 1. Tender Owner changes
    // 2. Bidders Owner changes
    // 3. Bidder Contact Details Owner changes
    // 4. Tender AI Summary Owner changes
    // 5. Tender Document Details Owner changes
    //
    // multiDepartmentUser (newOwner) has Departments__c mapped to
    // TENDER_DEPARTMENT, so TenderOwnerValidationHandler's before-update
    // check passes.
    // ============================================================

    @IsTest
    static void testUpdateOwnerAndCascade() {

        User oldOwner = [
            SELECT Id
            FROM User
            WHERE LastName = 'Owner'
            LIMIT 1
        ];

        User newOwner = [
            SELECT Id
            FROM User
            WHERE LastName = 'Department'
            LIMIT 1
        ];

        Tender__c tender = createTender(oldOwner.Id);

        // --------------------------------------------------------
        // Create related records
        // --------------------------------------------------------

        Bidders__c bidder = new Bidders__c(
            Tender__c = tender.Id,
            OwnerId = oldOwner.Id
        );

        Bidders_Contact_Details__c contact =
            new Bidders_Contact_Details__c(
                Tender__c = tender.Id,
                OwnerId = oldOwner.Id
            );

        Tender_Ai_Summary_Json__c summary =
            new Tender_Ai_Summary_Json__c(
                Tender__c = tender.Id,
                OwnerId = oldOwner.Id
            );

        Tender_Docoment_Details__c documentDetail =
            new Tender_Docoment_Details__c(
                Tender__c = tender.Id,
                OwnerId = oldOwner.Id
            );

Database.insert(bidder, AccessLevel.SYSTEM_MODE);
Database.insert(contact, AccessLevel.SYSTEM_MODE);
Database.insert(summary, AccessLevel.SYSTEM_MODE);
Database.insert(documentDetail, AccessLevel.SYSTEM_MODE);

        Test.startTest();

        TenderOwnerChangeController.updateOwner(
            tender.Id,
            newOwner.Id
        );

        Test.stopTest();

        // --------------------------------------------------------
        // Verify Tender Owner
        // --------------------------------------------------------

        Tender__c updatedTender = [
            SELECT Id,
                   OwnerId,
                   Department_Name__c
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            newOwner.Id,
            updatedTender.OwnerId,
            'Tender Owner should be changed.'
        );

        // Department must NOT change.
        System.assertEquals(
            tender.Department_Name__c,
            updatedTender.Department_Name__c,
            'Department must remain unchanged.'
        );

        // --------------------------------------------------------
        // Verify Bidder Owner
        // --------------------------------------------------------

        Bidders__c updatedBidder = [
            SELECT Id, OwnerId
            FROM Bidders__c
            WHERE Id = :bidder.Id
        ];

        System.assertEquals(
            newOwner.Id,
            updatedBidder.OwnerId,
            'Bidder Owner should be changed.'
        );

        // --------------------------------------------------------
        // Verify Contact Owner
        // --------------------------------------------------------

        Bidders_Contact_Details__c updatedContact = [
            SELECT Id, OwnerId
            FROM Bidders_Contact_Details__c
            WHERE Id = :contact.Id
        ];

        System.assertEquals(
            newOwner.Id,
            updatedContact.OwnerId,
            'Bidder Contact Details Owner should be changed.'
        );

        // --------------------------------------------------------
        // Verify AI Summary Owner
        // --------------------------------------------------------

        Tender_Ai_Summary_Json__c updatedSummary = [
            SELECT Id, OwnerId
            FROM Tender_Ai_Summary_Json__c
            WHERE Id = :summary.Id
        ];

        System.assertEquals(
            newOwner.Id,
            updatedSummary.OwnerId,
            'Tender AI Summary Owner should be changed.'
        );

        // --------------------------------------------------------
        // Verify Document Detail Owner
        // --------------------------------------------------------

        Tender_Docoment_Details__c updatedDocument =
            [
                SELECT Id, OwnerId
                FROM Tender_Docoment_Details__c
                WHERE Id = :documentDetail.Id
            ];

        System.assertEquals(
            newOwner.Id,
            updatedDocument.OwnerId,
            'Tender Document Detail Owner should be changed.'
        );
    }


    // ============================================================
    // Test updateOwner() - Null Tender Id
    // ============================================================

    @IsTest
    static void testUpdateOwnerNullTenderId() {

        User owner = [
            SELECT Id
            FROM User
            WHERE LastName = 'Department'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TenderOwnerChangeController.updateOwner(
                null,
                owner.Id
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException should be thrown when Tender Id is null.'
        );
    }


    // ============================================================
    // Test updateOwner() - Null Owner Id
    // ============================================================

    @IsTest
    static void testUpdateOwnerNullOwnerId() {

        User owner = [
            SELECT Id
            FROM User
            WHERE LastName = 'Owner'
            LIMIT 1
        ];

        Tender__c tender = createTender(owner.Id);

        Boolean exceptionThrown = false;

        Test.startTest();

        try {

            TenderOwnerChangeController.updateOwner(
                tender.Id,
                null
            );

        } catch (AuraHandledException e) {

            exceptionThrown = true;
        }

        Test.stopTest();

        System.assertEquals(
            true,
            exceptionThrown,
            'AuraHandledException should be thrown when Owner Id is null.'
        );
    }


    // ============================================================
    // Test updateOwner() - Same Owner
    //
    // Verifies the early return:
    //
    // if (tender.OwnerId == ownerId) {
    //     return;
    // }
    //
    // Owner is unchanged, so TenderOwnerValidationHandler's
    // "Owner changed" guard clause skips validation entirely - no
    // Departments__c matching is required here.
    // ============================================================

    @IsTest
    static void testUpdateOwnerSameOwner() {

        User owner = [
            SELECT Id
            FROM User
            WHERE LastName = 'Owner'
            LIMIT 1
        ];

        Tender__c tender = createTender(owner.Id);

        Test.startTest();

        TenderOwnerChangeController.updateOwner(
            tender.Id,
            owner.Id
        );

        Test.stopTest();

        Tender__c result = [
            SELECT Id, OwnerId
            FROM Tender__c
            WHERE Id = :tender.Id
        ];

        System.assertEquals(
            owner.Id,
            result.OwnerId,
            'Owner should remain unchanged.'
        );
    }
}