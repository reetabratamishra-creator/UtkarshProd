@IsTest
private class CaseCreatorShareHandlerTest {
  @IsTest
  static void testNullAndEmptyGuards() {
    CaseCreatorShareHandler.handleAfterInsert(null);
    CaseCreatorShareHandler.handleAfterInsert(new List<Case>());
    CaseCreatorShareHandler.handleAfterUpdate(null, null);
    CaseCreatorShareHandler.handleAfterUpdate(new List<Case>(), new Map<Id, Case>());
  }

  @IsTest
  static void testCreatorShareOnInsertAndOwnerChange() {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      WITH SYSTEM_MODE
      LIMIT 1
    ];

    Long stamp = System.currentTimeMillis();
    User creatorUser = buildUser(profileRecord.Id, 'cshr1' + stamp, 'CreatorShare');
    User ownerUser = buildUser(profileRecord.Id, 'cshr2' + stamp, 'OwnerShare');
    insert as system new List<User>{ creatorUser, ownerUser };

    Case caseRecord = new Case(
      Subject = 'Share Handler Case',
      Status = 'New',
      Origin = 'Phone',
      OwnerId = ownerUser.Id,
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get('Case')
        .getRecordTypeId()
    );

    System.runAs(creatorUser) {
      insert as system caseRecord;
    }

    caseRecord = [
      SELECT Id, CaseNumber, OwnerId, CreatedById, RecordTypeId, Department__c, IsClosed, Status
      FROM Case
      WHERE Id = :caseRecord.Id
      WITH SYSTEM_MODE
    ];

    CaseCreatorShareHandler.handleAfterInsert(new List<Case>{ caseRecord });

    User thirdOwner = buildUser(profileRecord.Id, 'cshr3' + stamp, 'ThirdOwner');
    insert as system thirdOwner;

    Case oldCase = caseRecord.clone(true, true, true, true);
    caseRecord.OwnerId = thirdOwner.Id;
    CaseCreatorShareHandler.handleAfterUpdate(
      new List<Case>{ caseRecord },
      new Map<Id, Case>{ caseRecord.Id => oldCase }
    );

    System.assertEquals(thirdOwner.Id, caseRecord.OwnerId);
  }

  @IsTest
  static void testBeforeUpdateLocksForStandardUser() {
    Profile profileRecord = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Long stamp = System.currentTimeMillis();
    User editor = buildUser(profileRecord.Id, 'cshr4' + stamp, 'LockEditor');
    User otherOwner = buildUser(profileRecord.Id, 'cshr5' + stamp, 'LockOwner');
    insert as system new List<User>{ editor, otherOwner };

    Map<String, Schema.RecordTypeInfo> recordTypes =
      Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName();
    Id caseTypeId = recordTypes.get('Case').getRecordTypeId();
    Id ticketTypeId = recordTypes.get('Internal_Ticket').getRecordTypeId();

    // In-memory cases (no DML): the before-update checks only read the old/new values.
    Case ticketOld = memoryCase('500000000000001AAA', ticketTypeId, otherOwner.Id, editor.Id, 'New', 'Ticket', null);
    Case ticketNew = memoryCase('500000000000001AAA', ticketTypeId, otherOwner.Id, editor.Id, 'New', 'Ticket edited', null);
    Case resolvedOld = memoryCase('500000000000002AAA', caseTypeId, otherOwner.Id, otherOwner.Id, 'Resolved', 'Resolved', null);
    Case resolvedNew = memoryCase('500000000000002AAA', caseTypeId, otherOwner.Id, otherOwner.Id, 'Resolved', 'Resolved edited', null);
    Case creatorOld = memoryCase('500000000000003AAA', caseTypeId, otherOwner.Id, editor.Id, 'New', 'Assigned', null);
    Case creatorNew = memoryCase('500000000000003AAA', caseTypeId, otherOwner.Id, editor.Id, 'New', 'Assigned', 'Creator note');
    Case openOld = memoryCase('500000000000004AAA', caseTypeId, editor.Id, editor.Id, 'New', 'Own case', null);
    Case openNew = memoryCase('500000000000004AAA', caseTypeId, editor.Id, editor.Id, 'New', 'Own case edited', null);

    Test.startTest();
    System.runAs(editor) {
      CaseCreatorShareHandler.handleBeforeUpdate(null, null);
      CaseCreatorShareHandler.handleBeforeUpdate(
        new List<Case>{ ticketNew, resolvedNew, creatorNew, openNew },
        new Map<Id, Case>{
          ticketOld.Id => ticketOld,
          resolvedOld.Id => resolvedOld,
          creatorOld.Id => creatorOld,
          openOld.Id => openOld
        }
      );
    }
    Test.stopTest();

    System.assert(ticketNew.hasErrors(), 'Only the ticket owner can edit a ticket.');
    System.assert(resolvedNew.hasErrors(), 'A Resolved case is locked for non-admins.');
    System.assert(creatorNew.hasErrors(), 'The creator cannot edit a case owned by someone else.');
    System.assert(!openNew.hasErrors(), 'The owner can edit their own open case.');
  }

  private static Case memoryCase(
    String caseId,
    Id recordTypeId,
    Id ownerId,
    Id createdById,
    String status,
    String subject,
    String description
  ) {
    Map<String, Object> fields = new Map<String, Object>{
      'attributes' => new Map<String, Object>{ 'type' => 'Case' },
      'Id' => caseId,
      'RecordTypeId' => recordTypeId,
      'OwnerId' => ownerId,
      'CreatedById' => createdById,
      'Status' => status,
      'Subject' => subject
    };
    if (description != null) {
      fields.put('Description', description);
    }
    return (Case) JSON.deserialize(JSON.serialize(fields), Case.class);
  }

  private static User buildUser(Id profileId, String uniqueKey, String lastName) {
    return new User(
      Alias = uniqueKey.left(8),
      Email = uniqueKey + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = lastName,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileId,
      TimeZoneSidKey = 'Asia/Kolkata',
      Username = uniqueKey + '@example.com'
    );
  }
}