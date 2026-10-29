/**
 * @description   Test class for EscalationMatrixOpportunityHelper.
 * @author        Anshita Chanda
 * @date          2026-08-17
 */
@IsTest
private class EscalationMatrixOpportunityHelperTest {
  @IsTest
  static void testGetLastActivityDatesFromTasksAndEvents() {
    EscalationMatrixOpportunityHelper.clearTestLastActivityDates();

    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Helper Opp',
      false,
      null
    );

    insert new Task(
      WhatId = opportunityRecord.Id,
      Subject = 'Old Task',
      Status = 'Completed',
      ActivityDate = Date.today().addDays(-3)
    );
    insert new Event(
      WhatId = opportunityRecord.Id,
      Subject = 'Old Event',
      DurationInMinutes = 30,
      ActivityDateTime = System.now().addDays(-1)
    );

    Map<Id, Date> activityDates = EscalationMatrixOpportunityHelper.getLastActivityDates(
      new Set<Id>{ opportunityRecord.Id }
    );

    System.assertNotEquals(null, activityDates.get(opportunityRecord.Id));
  }

  @IsTest
  static void testHoursSinceDateAndEmptyInput() {
    EscalationMatrixOpportunityHelper.clearTestLastActivityDates();

    System.assertEquals(0, EscalationMatrixOpportunityHelper.hoursSinceDate(null));
    System.assert(
      EscalationMatrixOpportunityHelper.hoursSinceDate(Date.today().addDays(-4)) >= 72
    );
    System.assertEquals(
      0,
      EscalationMatrixOpportunityHelper.getLastActivityDates(null).size()
    );
    System.assertEquals(
      0,
      EscalationMatrixOpportunityHelper.getLastActivityDates(new Set<Id>()).size()
    );
  }

  @IsTest
  static void testTestOverridePath() {
    Opportunity opportunityRecord = EscalationMatrixTestUtil.createOpportunity(
      'Nurture',
      'Override Opp',
      false,
      null
    );
    EscalationMatrixOpportunityHelper.clearTestLastActivityDates();
    EscalationMatrixOpportunityHelper.setTestLastActivityDate(
      opportunityRecord.Id,
      Date.today().addDays(-10)
    );

    Map<Id, Date> activityDates = EscalationMatrixOpportunityHelper.getLastActivityDates(
      new Set<Id>{ opportunityRecord.Id }
    );
    System.assertEquals(Date.today().addDays(-10), activityDates.get(opportunityRecord.Id));
  }
}