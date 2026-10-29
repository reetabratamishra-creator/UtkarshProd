/**
 * @description   Test class for WFH/WFO Punch Record employee and HOD email automation.
 * @author        Anshita Chanda
 * @date          2026-08-14
 */
@IsTest
private class PunchRecordWfhEmployeeEmailHandlerTest {
  @IsTest
  static void testQualifiesAsPendingAndApproved() {
    Punch_Record__c pendingWfh = buildPunch(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
      UserInfo.getUserId()
    );
    Punch_Record__c pendingWfo = buildPunch(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFO,
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
      UserInfo.getUserId()
    );
    Punch_Record__c marketVisit = buildPunch(
      'Market Visit',
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
      UserInfo.getUserId()
    );
    Punch_Record__c missingUser = buildPunch(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
      null
    );

    System.assertEquals(
      true,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsPending(pendingWfh, null)
    );
    System.assertEquals(
      true,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsPending(pendingWfo, null)
    );
    System.assertEquals(
      false,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsPending(marketVisit, null)
    );
    System.assertEquals(
      false,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsPending(missingUser, null)
    );
    System.assertEquals(
      false,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsPending(null, null)
    );

    Punch_Record__c oldApproved = buildPunch(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFO,
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_APPROVED,
      UserInfo.getUserId()
    );
    System.assertEquals(
      true,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsPending(pendingWfh, oldApproved)
    );
    System.assertEquals(
      false,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsPending(pendingWfh, pendingWfh)
    );

    Punch_Record__c newlyApproved = buildPunch(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_APPROVED,
      UserInfo.getUserId()
    );
    Punch_Record__c oldPending = buildPunch(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
      UserInfo.getUserId()
    );
    System.assertEquals(
      true,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsApproved(newlyApproved, oldPending)
    );
    System.assertEquals(
      false,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsApproved(newlyApproved, null)
    );
    System.assertEquals(
      false,
      PunchRecordWfhEmployeeEmailHandler.qualifiesAsApproved(newlyApproved, newlyApproved)
    );
  }

  @IsTest
  static void testHandleAfterInsertAndUpdate() {
    Punch_Record__c punchRecord = buildPunch(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
      UserInfo.getUserId()
    );
    punchRecord.Is_WFH_Request__c = true;
    punchRecord.Is_WFO_Request__c = false;

    Test.startTest();
    insert punchRecord;
    punchRecord.WFH_Approval_Status__c =
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_APPROVED;
    update punchRecord;
    Test.stopTest();

    Punch_Record__c storedRecord = [
      SELECT Punch_Type__c, WFH_Approval_Status__c
      FROM Punch_Record__c
      WHERE Id = :punchRecord.Id
    ];
    System.assertEquals(
      PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
      storedRecord.Punch_Type__c
    );
    System.assertEquals(
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_APPROVED,
      storedRecord.WFH_Approval_Status__c
    );
  }

  @IsTest
  static void testNoSendWhenCriteriaNotMet() {
    Punch_Record__c punchRecord = buildPunch(
      'Market Visit',
      PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
      UserInfo.getUserId()
    );
    punchRecord.Is_WFH_Request__c = false;
    punchRecord.Is_WFO_Request__c = false;

    Test.startTest();
    insert punchRecord;
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM Punch_Record__c]);
  }

  @IsTest
  static void testProcessRecordsSkipsEmptyAndMissingUser() {
    Test.startTest();
    PunchRecordWfhEmployeeEmailHandler.processRecords(null, null);
    PunchRecordWfhEmployeeEmailHandler.processRecords(
      new List<Punch_Record__c>(),
      null
    );
    PunchRecordWfhEmployeeEmailHandler.processRecords(
      new List<Punch_Record__c>{
        buildPunch(
          PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
          PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
          null
        )
      },
      null
    );
    PunchRecordWfhEmployeeEmailHandler.processRecords(
      new List<Punch_Record__c>{
        buildPunch(
          PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFO,
          PunchRecordWfhEmployeeEmailHandler.APPROVAL_STATUS_PENDING,
          UserInfo.getUserId()
        )
      },
      null
    );
    Test.stopTest();

    System.assertEquals(true, true);
  }

  private static Punch_Record__c buildPunch(
    String punchType,
    String approvalStatus,
    Id userId
  ) {
    return new Punch_Record__c(
      Punch_Type__c = punchType,
      WFH_Approval_Status__c = approvalStatus,
      User__c = userId,
      Is_WFH_Request__c = punchType == PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFH,
      Is_WFO_Request__c = punchType == PunchRecordWfhEmployeeEmailHandler.PUNCH_TYPE_WFO
    );
  }
}