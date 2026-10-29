/**
 * @description   Test class for LeadProspectNotContacted48_96Batch.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class LeadProspectNotContacted48_96BatchTest {
  @IsTest
  static void testStartExecuteFinish() {
    EscalationMatrixTestUtil.prepareTestContext();

    Test.startTest();
    Database.QueryLocator locator = new LeadProspectNotContacted48_96Batch().start(null);
    new LeadProspectNotContacted48_96Batch().finish(null);
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void testExecute48HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'Prospect48');
    leadRecord.Prospect_Stage_Entry_Date__c = System.now().addHours(-50);
    leadRecord.Escalation_48_Sent__c = false;
    leadRecord.Escalation_72_Sent__c = false;
    update leadRecord;

    leadRecord = EscalationMatrixTestUtil.queryProspectLead(leadRecord.Id);

    Test.startTest();
    new LeadProspectNotContacted48_96Batch().execute(null, new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = [
      SELECT Escalation_48_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(true, updatedLead.Escalation_48_Sent__c);
  }

  @IsTest
  static void testExecute96HourEscalation() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'Prospect96');
    leadRecord.Prospect_Stage_Entry_Date__c = System.now().addHours(-100);
    leadRecord.Escalation_48_Sent__c = true;
    leadRecord.Escalation_72_Sent__c = false;
    update leadRecord;

    leadRecord = EscalationMatrixTestUtil.queryProspectLead(leadRecord.Id);

    Test.startTest();
    new LeadProspectNotContacted48_96Batch().execute(null, new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = [
      SELECT Escalation_72_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(true, updatedLead.Escalation_72_Sent__c);
  }

  @IsTest
  static void testSkipsWhenRecentActivity() {
    EscalationMatrixTestUtil.prepareTestContext();

    Lead leadRecord = EscalationMatrixTestUtil.createLead('Prospect', 'ProspectSkip');
    leadRecord.Prospect_Stage_Entry_Date__c = System.now().addHours(-50);
    leadRecord.Escalation_48_Sent__c = false;
    update leadRecord;

    insert new Task(
      WhoId = leadRecord.Id,
      Subject = 'Recent Activity',
      Status = 'Completed',
      ActivityDate = Date.today()
    );

    leadRecord = EscalationMatrixTestUtil.queryProspectLead(leadRecord.Id);

    Test.startTest();
    new LeadProspectNotContacted48_96Batch().execute(null, new List<Lead>{ leadRecord });
    Test.stopTest();

    Lead updatedLead = [
      SELECT Escalation_48_Sent__c
      FROM Lead
      WHERE Id = :leadRecord.Id
    ];
    System.assertEquals(false, updatedLead.Escalation_48_Sent__c);
  }
}