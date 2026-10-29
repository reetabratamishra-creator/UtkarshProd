public without sharing class TenderHODController {


    public class UserOption {
    @AuraEnabled public String label;
    @AuraEnabled public Id value;

    public UserOption(String label, Id value) {
        this.label = label;
        this.value = value;
    }
    }

    @AuraEnabled(cacheable=true)
    public static Account getTenderAccount(Id tenderId) {
        Tender__c tender = [
            SELECT Authority__c
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (tender.Authority__c == null) {
            return null;
        }

        return [
            SELECT Id, Name, BillingCity, BillingState, Phone, Website // adjust to fields you actually need
            FROM Account
            WHERE Id = :tender.Authority__c
            WITH SYSTEM_MODE
            LIMIT 1
        ];
    }


    @AuraEnabled(cacheable=true)
public static List<Address_Book__c> getAddressBookDetails(Id tenderId) {
    List<Tender_Addressbook_Junc__c> junctions = [
        SELECT Address_Book__c
        FROM Tender_Addressbook_Junc__c
        WHERE Tender__c = :tenderId
        WITH SYSTEM_MODE
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    if (junctions.isEmpty()) {
        return new List<Address_Book__c>();
    }

    Set<Id> abIds = new Set<Id>();
    for (Tender_Addressbook_Junc__c j : junctions) {
        abIds.add(j.Address_Book__c);
    }

    return [
        SELECT Id, Name, City__c, State__c,Street__c,PIN__c// adjust to real fields
        FROM Address_Book__c
        WHERE Id IN :abIds
        WITH SYSTEM_MODE
    ];
}


    @AuraEnabled(cacheable=true)
public static List<UserOption> getProjectOwners(Id tenderId,String userListChoice) {

    Map<String, String> deptMap = new Map<String, String>{
    'High Mast & Polygonal'             => 'High_Mast_Department',
    'Crash Barrier'                     => 'Crash_Barrier_Department',
    'HDPE'                              => 'HDPE_Pipe_Department',
    'Steel Tubular Poles'               => 'Steel_Tubular_Pole_Department',
    'Polymer'                           => 'PVC',
    'Transmission & Telecom Tower'      => 'Transmission_Tower_Department',
    'Pre Engineering Building'          => 'PEB',
    'Solar Structure'                   => 'Solar_Structure_Department',
    'Railway Electrification Structure' => 'Core_Department',
    'Steel Pipes'                       => 'Steel_Pipes_Department'
    };

    Tender__c tender = [
        SELECT Department_Name__c,Name
        FROM Tender__c
        WHERE Id = :tenderId
        WITH SYSTEM_MODE
        
    ];
    System.debug(tender.Department_Name__c);
    String userDepartment = deptMap.get(tender.Department_Name__c);
    System.debug('User Department'+userDepartment);
    if (String.isBlank(userDepartment)) {
        return new List<UserOption>();
    }

    List<UserOption> options = new List<UserOption>();
    if(userListChoice=='project')
    {
        List<User> userList=[
        SELECT Id, Name
        FROM User
        WHERE IsActive = true
        AND Departments__c INCLUDES(:userDepartment)
        AND IsActive=true
        AND (
            
            Profile.Name = 'Utkarsh Projects' OR
            Project_Access_User__c=true
        )
        WITH SYSTEM_MODE
        ORDER BY Name
       ];
    
    for (User u : userList ) {
        options.add(new UserOption(u.Name, u.Id));
    }

    return options;
    }
    else if(userListChoice=='tender'){
        List<User> userList=[
        SELECT Id, Name
        FROM User
        WHERE IsActive = true
        AND Departments__c INCLUDES(:userDepartment)
        AND IsActive=true
        AND (
            
            Profile.Name = 'Utkarsh Tender' OR
            Tender_Access_User__c=true
            
        )
        WITH SYSTEM_MODE
        ORDER BY Name
       ];
    
    for (User u : userList ) {
        options.add(new UserOption(u.Name, u.Id));
    }
    return options;
    }
    return new List<UserOption>();
}

    @AuraEnabled(cacheable=true)
    public static List<String> getChoices() {

        List<String> values = new List<String>();

        Schema.DescribeFieldResult field =
            Tender__c.HOD_Choice__c.getDescribe();

        for(Schema.PicklistEntry p : field.getPicklistValues()){

            if(p.isActive()){
                values.add(p.getValue());
            }
        }

        return values;
    }

    
    @AuraEnabled
public static void processChoice(
    Id tenderId,
    String action,
    String rejectReason,
    Id projectOwnerId
) {

    Tender__c tender = [
        SELECT Id,
               Tender_User_Choice__c,Name,Department_Name__c,HOD_Comments__c
        FROM Tender__c
        WHERE Id = :tenderId
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Boolean isDirectParticipation =
    tender.Tender_User_Choice__c == 'Accept and participate';

Boolean isDirectParticipationRejection =
    tender.Tender_User_Choice__c == 'Reject and Create Project' ||
    tender.Tender_User_Choice__c == 'Reject and Close';
     

    switch on action {

        // -----------------------------
        // Tender Opportunity
        // -----------------------------
        when 'APPROVE_PARTICIPATION' {

            tender.HOD_Choice__c = 'Accept for participation';
            tender.HOD_Comments__c = appendComment(tender.HOD_Comments__c, rejectReason);
            tender.tender_User_Choice__c='';
            Database.update (tender, AccessLevel.SYSTEM_MODE);

            createTenderOpp(tenderId, projectOwnerId, isDirectParticipation);
        }

        // -----------------------------
        // Create Project
        // -----------------------------
        when 'CREATE_PROJECT' {

            tender.HOD_Choice__c = 'Reject and Create Project';
            tender.HOD_Comments__c = appendComment(tender.HOD_Comments__c, rejectReason);
            tender.tender_User_Choice__c='';
             Database.update(tender,AccessLevel.SYSTEM_MODE);

            createProject(
        tenderId,
        rejectReason,
        projectOwnerId,
        isDirectParticipation,
        isDirectParticipationRejection
    );
        }

        // -----------------------------
        // Close Tender
        // -----------------------------
        when 'CLOSE_TENDER' {

            tender.HOD_Choice__c = 'Reject and Close';
            tender.HOD_Comments__c = appendComment(tender.HOD_Comments__c, rejectReason);
            tender.tender_User_Choice__c='';
            Database.update (tender, AccessLevel.SYSTEM_MODE);

            closeTenderAsLost(
        tenderId,
        rejectReason,
        isDirectParticipation,
        isDirectParticipationRejection
    );
        }

        // -----------------------------
        // Update Account Details
        // -----------------------------
        when 'UPDATE_ACCOUNT' {

            tender.HOD_Choice__c = 'Update Account Details';
            tender.tender_User_Choice__c='';
            tender.HOD_Comments__c = appendComment(tender.HOD_Comments__c, rejectReason);
            tender.Tender_Stage__c='Open';
            Database.update (tender, AccessLevel.SYSTEM_MODE);
            String notiTitle='Tender needs review';
            String notiBody='Please recheck '+tender.Name+' and send back';
            // we'll replace this later with account update logic
            sendReviewNotification(tenderId,notiBody,notiTitle);

    //         if (isDirectParticipation) {
    //     notifyDirectParticipationRejected(tender);
    // }
        }

        // -----------------------------
        // Send Back for Participation
        // -----------------------------
        when 'SEND_BACK_TO_PARTICIPATE' {

    tender.HOD_Choice__c = 'Review and resend for participation';
    tender.HOD_Comments__c = appendComment(tender.HOD_Comments__c, rejectReason);
    tender.tender_User_Choice__c = '';
    tender.Tender_Stage__c = 'Open';

    Database.update(tender, AccessLevel.SYSTEM_MODE);

    if (isDirectParticipationRejection) {

        notifyDirectParticipationRejectionRejected(tenderId);

    } else {

        String notiTitle = 'Tender needs review';
        String notiBody = 'Please recheck ' + tender.Name + ' and send back';

        sendReviewNotification(
            tenderId,
            notiBody,
            notiTitle
        );
    }
}

        when else {
            throw new AuraHandledException('Invalid action.');
        }
    }
}

    private static void closeTenderAsLost(Id tenderId,String rejectReason , Boolean isDirectParticipation, Boolean isDirectParticipationRejection) {
        Database.update(
            new Tender__c(
                Id = tenderId,
                Tender_Stage__c = 'Closed Rejected'
            ),
            AccessLevel.SYSTEM_MODE
        );
        Tender__c tender = [
            SELECT Id, Name,Department_Name__c, OwnerId
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
if (isDirectParticipationRejection) {

    notifyDirectParticipationRejectionAccepted(tender);

} else if (isDirectParticipation) {

    notifyDirectParticipationRejected(tender);

} else {

    String body = 'Your tender ' + tender.Name + ' was rejected';
    String title = 'Tender lost';

    sendReviewNotification(
        tenderId,
        body,
        title
    );
}
    }

    @AuraEnabled
    public static void acceptParticipationDirect(Id tenderId, Id projectOwnerId, String notes) {

        if (tenderId == null) {
            throw new AuraHandledException('Tender record is required.');
        }
        if (projectOwnerId == null) {
            throw new AuraHandledException('Project Owner is required.');
        }

        Tender__c tender = [
            SELECT Id, Name, Tender_User_Choice__c, HOD_Comments__c
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        tender.Tender_User_Choice__c = 'Accept and participate';
        tender.HOD_Comments__c = appendComment(tender.HOD_Comments__c, notes);
        tender.HOD_Choice__c = 'Accept for participation';

        Database.update(tender, AccessLevel.SYSTEM_MODE);

        // Calls the existing PRIVATE createTenderOpp — allowed because we're inside the same class
        createTenderOpp(tenderId, projectOwnerId, true);
    }

    private static void sendReviewNotification(Id tenderId,String tenderBody,String tenderTitle) {

     Tender__c tender = [
            SELECT Id, Name,Department_Name__c, OwnerId
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        

        if (tender.OwnerId == null) {
            return;
        }

        CustomNotificationType notifType = [
            SELECT Id
            FROM CustomNotificationType
            WHERE DeveloperName = 'Tender_Approval_Notification'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle(tenderTitle);
        notification.setBody(tenderBody);
        notification.setNotificationTypeId(notifType.Id);
        System.debug(notifType.id);
        notification.setTargetId(tender.Id); 
        System.debug(tender.Id);// navigates to the Tender record on click
        Set<String> recipients = new Set<String>{
           String.valueOf(tender.OwnerId)
            };

        System.debug(recipients);

        //notification.send(recipients);
        try {
            notification.send(new Set<String>{ tender.OwnerId });
        } catch (Exception e) {
            // Custom notifications shouldn't block the main transaction if they fail
            System.debug('Failed to send review notification: ' + e.getMessage());
        }
    }
    /**
     * Approve branch of the "Tender: Approval Process" flow.
     * Creates the parent Tender Opportunity, links an Address Book record,
     * and marks the Tender as Closed Accepted.
     */
    private static void createTenderOpp(Id tenderId,Id projectOwnerId,Boolean isDirectParticipation ) {
        Tender__c tender = [
            SELECT Id, Name, Authority__c, Authority__r.Name,Department_Name__c, OwnerId,
                   Tender_Value__c, Biddead_Line__c, CreatedDate
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        List<ContentDocumentLink> tenderFiles = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :tenderId
            WITH SYSTEM_MODE
        ];
        Id tenderOppRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Tender_Opportunity'
            WITH SYSTEM_MODE
            LIMIT 1
        ].Id;

        // --- Screen-derived inputs in the original flow; defaulted here ---
        // TODO: replace with real selected/created Contact Id (Add_Contact_Screen)
        Id contactId = getDefaultContactId(tender.Id);
        // TODO: replace with real selected/created Address Book Id (AddressBook_Selection_screen)
        Id addressBookId = getAddressBookId(tender.Id);
        // TODO: replace with actual HOD approval note text entered on Screen1
        String approvalNoteText = '';
        Date closeDate = calculateCloseDate(tender.Biddead_Line__c, tender.CreatedDate);
        Decimal amount = parseTenderValue(tender.Tender_Value__c);
        System.debug('Project owner'+projectOwnerId);
        Opportunity opp = new Opportunity(
            AccountId          = tender.Authority__c,
            Amount             = amount,
            CloseDate          = closeDate,
            ContactId          = contactId,
            Customer_Journey__c = 'Direct Business',
            Department_Name__c = tender.Department_Name__c,
            Name               = tender.Department_Name__c + '-' + tender.Authority__r.Name,
            OwnerId            = projectOwnerId,
            RecordTypeId       = tenderOppRecordTypeId,
            StageName          = 'Negotiation',
            Tender__c          = tender.Id,
            isParent__c        = true,
            Sub_Stage__c       ='Tender',
            Opportunity_Source__c='TENDER'
        );
        Database.insert(opp, AccessLevel.SYSTEM_MODE);

        if (projectOwnerId != null) {                                    
            notifyRecordOwner(
                projectOwnerId,
                opp.Id,
                'A new Tender Opportunity assigned',
                'A new Tender Opportunity has been assigned to you. Please review and initiate follow-up '+ opp.Name
            );
        }

 if (isDirectParticipation) {
    notifyDirectParticipationAccepted(
        tender,
        opp.Id
    );
} else {
    String body = 'Your tender ' + tender.Name + ' was approved';
    String title = 'Tender Approved';

    sendReviewNotification(
        tender.Id,
        body,
        title
    );
}
       
        List<Opportunity_Address_Junc__c> juncList=new List<Opportunity_Address_Junc__c>();

        if (addressBookId != null) {
            juncList.add(new Opportunity_Address_Junc__c(
                Opportunity__c = opp.Id,
                Address_Book__c = addressBookId
            ));
        }

        try{
            database.insert(juncList, AccessLevel.SYSTEM_MODE);
        } catch(Exception e){
            throw new AuraHandledException('An error occured while inserting address book: '+ e.getMessage());
        }

        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();

        for (ContentDocumentLink file : tenderFiles) {
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = file.ContentDocumentId,
                LinkedEntityId = opp.Id,
                ShareType = 'V',          // Viewer
                Visibility = 'AllUsers'   // or InternalUsers, SharedUsers
            ));
        }

        if (!newLinks.isEmpty()) {
            Database.insert(newLinks,AccessLevel.SYSTEM_MODE);
        }
        

        /*if (contactId != null) {
            OpportunityContactRole ocr = new OpportunityContactRole(
                OpportunityId = opp.Id,
                ContactId = contactId,
                Role = 'Decision Maker', // Change if needed
                IsPrimary = true
            );

            Database.insert (ocr, AccessLevel.SYSTEM_MODE);
        }*/

        Database.update(
            new Tender__c(
                Id = tender.Id,
                Tender_Stage__c = 'Closed Accepted'
            ),
            AccessLevel.SYSTEM_MODE
        );

    }

    /**
     * Reject -> "Create Project" branch of the flow.
     * Creates the Project__c, relinks all Bidders__c for this Tender to it,
     * and marks the Tender as Closed Rejected.
     */
    private static void createProject(Id tenderId,String rejectReason,Id projectOwnerId, Boolean isDirectParticipation,Boolean isDirectParticipationRejection) {
        Tender__c tender = [
            SELECT Id, Name, Authority__c, Department_Name__c,
                   Biddead_Line__c,OwnerId, CreatedDate
            FROM Tender__c
            WHERE Id = :tenderId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        List<ContentDocumentLink> tenderFiles = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :tenderId
            WITH SYSTEM_MODE
        ];

        Date projectEndDate = calculateCloseDate(tender.Biddead_Line__c, tender.CreatedDate);

        Project__c project = new Project__c(
            Department_Name__c     = tender.Department_Name__c,
            Name                   = tender.Name,
            Project_Authoritise__c = tender.Authority__c,
            Project_End_Date__c    = projectEndDate,
            Tender_Lost__c         = true,
            Tender__c              = tender.Id,
            OwnerId                = projectOwnerId
        );
        
        Database.insert(project,AccessLevel.SYSTEM_MODE); 

        if (projectOwnerId != null) {                                    
            notifyRecordOwner(
                projectOwnerId,
                project.Id,
                'You have been assigned a new Project',
                project.Name + ' has been assigned to you'
            );
        }
         
        System.debug('created project'+project.Name);

        List<Bidders__c> biddersToLink = [
            SELECT Id, Project__c
            FROM Bidders__c
            WHERE Tender__c = :tenderId
            WITH SYSTEM_MODE
        ];
        if (!biddersToLink.isEmpty()) {
            for (Bidders__c b : biddersToLink) {
                b.Project__c = project.Id;
            }
            Database.update (biddersToLink,AccessLevel.SYSTEM_MODE);
        }

        Database.update(
            new Tender__c(
                Id = tender.Id,
                Tender_Stage__c = 'Closed Rejected'
            ),
            AccessLevel.SYSTEM_MODE
        );

        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();

        for (ContentDocumentLink file : tenderFiles) {
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = file.ContentDocumentId,
                LinkedEntityId = project.Id,
                ShareType = 'V',          // Viewer
                Visibility = 'AllUsers'   // or InternalUsers, SharedUsers
            ));
        }

        if (!newLinks.isEmpty()) {
            Database.insert(newLinks,AccessLevel.SYSTEM_MODE);
        }

        

  if (isDirectParticipationRejection) {

    notifyDirectParticipationRejectionAccepted(tender);

} else if (isDirectParticipation) {

    notifyDirectParticipationRejected(tender);

} else {

    String body = 'Your tender ' + tender.Name + ' was sent for project';
    String title = 'Tender Rejected and sent for Project';

    sendReviewNotification(
        tender.Id,
        body,
        title
    );
}
    }

    // ---------- Helpers (mirror the flow's formulas / lookups) ----------

    private static Date calculateCloseDate(Date biddeadLine, Datetime tenderCreatedDate) {
        // Mirrors CloseDateFormula: use Biddead_Line__c if present, else CreatedDate + 30
        if (biddeadLine != null) {
            return biddeadLine;
        }
        return tenderCreatedDate.date().addDays(30);
    }

    private static Decimal parseTenderValue(String tenderValue) {
        // Mirrors convertTenderValue formula: VALUE(Tender_Value__c), scale 2
        if (String.isBlank(tenderValue)) {
            return null;
        }
        return Decimal.valueOf(tenderValue).setScale(2);
    }

    private static Id getDefaultContactId(Id tenderId) {
        return [
        SELECT Contact__c
        FROM Tender__c
        WHERE Id = :tenderId
        WITH SYSTEM_MODE
        LIMIT 1
        ].Contact__c;
    }

    private static Id getAddressBookId(Id tenderId) {
    List<Tender_Addressbook_Junc__c> junctions = [
        SELECT Address_Book__c
        FROM Tender_Addressbook_Junc__c
        WHERE Tender__c = :tenderId
        WITH SYSTEM_MODE
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    return junctions.isEmpty() ? null : junctions[0].Address_Book__c;
}


private static String appendComment(String existingComments, String newComment) {

    if (String.isBlank(newComment)) {
        return existingComments;
    }

    String entry = '- ' + newComment;

    if (String.isBlank(existingComments)) {
        return entry;
    }

    return entry + '\n' + existingComments;
}

private static void notifyRecordOwner(Id ownerId, Id targetRecordId, String title, String body) {

    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Tender_Approval_Notification'
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Messaging.CustomNotification notification = new Messaging.CustomNotification();
    notification.setTitle(title);
    notification.setBody(body);
    notification.setNotificationTypeId(notifType.Id);
    notification.setTargetId(targetRecordId);

    try {
        notification.send(new Set<String>{ ownerId });
    } catch (Exception e) {
        System.debug('Failed to send owner assignment notification: ' + e.getMessage());
    }
}

private static void notifyDirectParticipationAccepted(
    Tender__c tender,
    Id opportunityId
) {
    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Tender_Approval_Notification'
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Set<String> recipients = new Set<String>();

    // Tender Owner
    if (tender.OwnerId != null) {
        recipients.add(String.valueOf(tender.OwnerId));
    }

    // CRM Heads belonging to the same department as the Tender
   Map<String, String> deptMap = new Map<String, String>{
    'High Mast & Polygonal'             => 'High_Mast_Department',
    'Crash Barrier'                     => 'Crash_Barrier_Department',
    'HDPE'                              => 'HDPE_Pipe_Department',
    'Steel Tubular Poles'               => 'Steel_Tubular_Pole_Department',
    'Polymer'                           => 'PVC',
    'Transmission & Telecom Tower'      => 'Transmission_Tower_Department',
    'Pre Engineering Building'          => 'PEB_Department',
    'Solar Structure'                   => 'Solar_Structure_Department',
    'Railway Electrification Structure' => 'Core_Department',
    'Steel Pipes'                       => 'Steel_Pipes_Department'
};

String userDepartment = deptMap.get(tender.Department_Name__c);

if (!String.isBlank(userDepartment)) {

    List<User> crmHeads = [
        SELECT Id, Name
        FROM User
        WHERE IsActive = true
        AND Profile.Name = 'CRM Head'
        AND Departments__c INCLUDES (:userDepartment)
        WITH SYSTEM_MODE
    ];

    for (User crmHead : crmHeads) {
        recipients.add(String.valueOf(crmHead.Id));
    }
}

    if (recipients.isEmpty()) {
        return;
    }

    Messaging.CustomNotification notification =
        new Messaging.CustomNotification();

    notification.setTitle('Direct Participation Accepted');

    notification.setBody(
        'Direct tender participation is approved. Click to access the opportunity.'
    );

    notification.setNotificationTypeId(notifType.Id);

    // Clicking the notification takes the user to the Opportunity
    notification.setTargetId(opportunityId);

    try {
        notification.send(recipients);
    } catch (Exception e) {
        System.debug(
            'Failed to send Direct Participation Accepted notification: ' +
            e.getMessage()
        );
    }
}

private static void notifyDirectParticipationRejected(
    Tender__c tender
) {
    if (tender.OwnerId == null) {
        return;
    }

    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Tender_Approval_Notification'
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Messaging.CustomNotification notification =
        new Messaging.CustomNotification();

    notification.setTitle(
        'Direct Participation request rejected'
    );

    notification.setBody(
        'Your direct tender participation request is rejected. Please review the remarks.'
    );

    notification.setNotificationTypeId(notifType.Id);

    // Keep the Tender as the target because the owner
    // needs to review the rejection remarks on the Tender.
    notification.setTargetId(tender.Id);

    try {
        notification.send(
            new Set<String>{
                String.valueOf(tender.OwnerId)
            }
        );
    } catch (Exception e) {
        System.debug(
            'Failed to send Direct Participation rejection notification: ' +
            e.getMessage()
        );
    }
}

private static void notifyDirectParticipationRejectionAccepted(
    Tender__c tender
) {
    if (tender.OwnerId == null) {
        return;
    }

    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Tender_Approval_Notification'
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    // =========================================================
    // TENDER OWNER RECIPIENTS
    // =========================================================
    Set<String> tenderOwnerRecipients = new Set<String>();
    tenderOwnerRecipients.add(String.valueOf(tender.OwnerId));


    // =========================================================
    // CRM HEAD / TENDER HOD RECIPIENTS
    // =========================================================
    Set<String> crmHeadRecipients = new Set<String>();

    Map<String, String> deptMap = new Map<String, String>{
        'High Mast & Polygonal'             => 'High_Mast_Department',
        'Crash Barrier'                     => 'Crash_Barrier_Department',
        'HDPE'                              => 'HDPE_Pipe_Department',
        'Steel Tubular Poles'               => 'Steel_Tubular_Pole_Department',
        'Polymer'                           => 'PVC',
        'Transmission & Telecom Tower'      => 'Transmission_Tower_Department',
        'Pre Engineering Building'          => 'PEB_Department',
        'Solar Structure'                   => 'Solar_Structure_Department',
        'Railway Electrification Structure' => 'Core_Department',
        'Steel Pipes'                       => 'Steel_Pipes_Department'
    };

    String userDepartment =
        deptMap.get(tender.Department_Name__c);

    if (!String.isBlank(userDepartment)) {

        List<User> crmHeads = [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND Profile.Name = 'CRM Head'
            AND Departments__c INCLUDES (:userDepartment)
            WITH SYSTEM_MODE
        ];

        for (User crmHead : crmHeads) {
            crmHeadRecipients.add(String.valueOf(crmHead.Id));
        }
    }


    // =========================================================
    // NOTIFICATION TO TENDER OWNER
    // =========================================================
    if (!tenderOwnerRecipients.isEmpty()) {

        Messaging.CustomNotification ownerNotification =
            new Messaging.CustomNotification();

        ownerNotification.setTitle(
            'Direct Participation Rejection accepted'
        );

        ownerNotification.setBody(
            'Your direct tender participation rejection has been approved.'
        );

        ownerNotification.setNotificationTypeId(notifType.Id);
        ownerNotification.setTargetId(tender.Id);

        try {
            ownerNotification.send(tenderOwnerRecipients);
        } catch (Exception e) {
            System.debug(
                'Failed to send notification to Tender Owner: ' +
                e.getMessage()
            );
        }
    }


    // =========================================================
    // NOTIFICATION TO CRM HEAD
    // =========================================================
    if (!crmHeadRecipients.isEmpty()) {

        Messaging.CustomNotification hodNotification =
            new Messaging.CustomNotification();

        hodNotification.setTitle(
            'Direct Participation Rejection accepted'
        );

        hodNotification.setBody(
            'Direct tender participation rejection has been approved.'
        );

        hodNotification.setNotificationTypeId(notifType.Id);
        hodNotification.setTargetId(tender.Id);

        try {
            hodNotification.send(crmHeadRecipients);
        } catch (Exception e) {
            System.debug(
                'Failed to send notification to CRM Head: ' +
                e.getMessage()
            );
        }
    }
}

private static void notifyDirectParticipationRejectionRejected(
    Id tenderId
) {

    Tender__c tender = [
        SELECT Id, OwnerId
        FROM Tender__c
        WHERE Id = :tenderId
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    if (tender.OwnerId == null) {
        return;
    }

    CustomNotificationType notifType = [
        SELECT Id
        FROM CustomNotificationType
        WHERE DeveloperName = 'Tender_Approval_Notification'
        WITH SYSTEM_MODE
        LIMIT 1
    ];

    Messaging.CustomNotification notification =
        new Messaging.CustomNotification();

    notification.setTitle(
        'Direct Participation Rejection accepted'
    );

    notification.setBody(
        'Your direct tender participation rejection request is rejected. Please review the remarks.'
    );

    notification.setNotificationTypeId(notifType.Id);
    notification.setTargetId(tender.Id);

    try {
        notification.send(
            new Set<String>{
                String.valueOf(tender.OwnerId)
            }
        );
    } catch (Exception e) {
        System.debug(
            'Failed to send Direct Participation Rejection rejected notification: ' +
            e.getMessage()
        );
    }
}


}