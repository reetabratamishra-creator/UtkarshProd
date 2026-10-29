/**
 * @description   Test class for LeadProspectingActivityHandler.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class LeadProspectingActivityHandlerTest {
  @IsTest
  static void testInsertProspectingLeadSetsActivityDate() {
    Lead leadRecord = new Lead(
      LastName = 'ProspectingInsert',
      Company = 'Handler Test Co',
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = 'Prospecting',
      Department_Name__c = 'Enquiry',
      Email = 'prospectinginsert@example.com',
      Phone = '9876543210'
    );

    Test.startTest();
    LeadProspectingActivityHandler.updateProspectingActivityDate(
      new List<Lead>{ leadRecord },
      null
    );
    insert leadRecord;
    Test.stopTest();

    Lead insertedLead = [
      SELECT Last_Prospecting_Activity__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertNotEquals(null, insertedLead.Last_Prospecting_Activity__c);
  }

  @IsTest
  static void testInsertNonProspectingLeadSkipsUpdate() {
    Lead leadRecord = new Lead(
      LastName = 'ProspectInsert',
      Company = 'Handler Test Co',
      LeadSource = 'OUTBOUND PHONE CALL',
      Status = 'Prospect',
      Department_Name__c = 'Enquiry',
      Email = 'prospectinsert@example.com',
      Phone = '9876543210'
    );

    LeadProspectingActivityHandler.updateProspectingActivityDate(
      new List<Lead>{ leadRecord },
      null
    );
    insert leadRecord;

    Lead insertedLead = [
      SELECT Last_Prospecting_Activity__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(null, insertedLead.Last_Prospecting_Activity__c);
  }

  @IsTest
  static void testUpdateIntoProspectingResetsFlags() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'MoveToProspecting');
    leadRecord.Prospecting_Escalation_24_Sent__c = true;
    leadRecord.Prospecting_Escalation_48_Sent__c = true;
    leadRecord.Prospecting_Escalation_72_Sent__c = true;
    update leadRecord;

    Lead oldLead = leadRecord.clone(true, true, true, true);
    leadRecord.Status = 'Prospecting';

    LeadProspectingActivityHandler.updateProspectingActivityDate(
      new List<Lead>{ leadRecord },
      new Map<Id, Lead>{ oldLead.Id => oldLead }
    );
    update leadRecord;

    Lead updatedLead = [
      SELECT
        Last_Prospecting_Activity__c,
        Prospecting_Escalation_24_Sent__c,
        Prospecting_Escalation_48_Sent__c,
        Prospecting_Escalation_72_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertNotEquals(null, updatedLead.Last_Prospecting_Activity__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_24_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_48_Sent__c);
    System.assertEquals(false, updatedLead.Prospecting_Escalation_72_Sent__c);
  }

  @IsTest
  static void testUpdateWhileProspectingRefreshesActivityDate() {
    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospecting', 'StayProspecting');
    Datetime firstActivity = System.now().addDays(-1);
    leadRecord.Last_Prospecting_Activity__c = firstActivity;
    update leadRecord;

    Lead oldLead = [
      SELECT Id, Status, Last_Prospecting_Activity__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    leadRecord.Phone = '9999999999';

    LeadProspectingActivityHandler.updateProspectingActivityDate(
      new List<Lead>{ leadRecord },
      new Map<Id, Lead>{ oldLead.Id => oldLead }
    );
    update leadRecord;

    Lead updatedLead = [
      SELECT Last_Prospecting_Activity__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assert(updatedLead.Last_Prospecting_Activity__c >= firstActivity);
  }
}