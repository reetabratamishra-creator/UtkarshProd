/**
 * @description   Test class for BWM_WaCampCtrlA Send WhatsApp Campaign entry points
 *                and BWM_CampaignScheduleContext.
 * @author        Anshita Chanda
 * @date          2026-10-23
 */
@IsTest
private class BWM_WaCampCtrlATest {
    private static final String SCHEDULE = '2026-10-24T05:30:00Z';

    @IsTest
    static void sendLeadWhatsAppRequiresSelection() {
        Boolean threw = false;
        try {
            BWM_WaCampCtrlA.sendLeadWhatsApp(new List<Id>(), 'tmpl');
        } catch (AuraHandledException ex) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void unscheduledSendsRequireSelection() {
        Integer threwCount = 0;
        Test.startTest();
        try {
            BWM_WaCampCtrlA.sendOpportunityWhatsApp(new List<Id>(), 'tmpl');
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        try {
            BWM_WaCampCtrlA.sendAccountWhatsApp(new List<Id>(), 'tmpl');
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        try {
            BWM_WaCampCtrlA.sendContactWhatsApp(new List<Id>(), 'tmpl');
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        try {
            BWM_WaCampCtrlA.sendOfflineCampaignWhatsApp(new List<Id>(), 'tmpl');
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        Test.stopTest();

        System.assertEquals(4, threwCount, 'Each send needs at least one record.');
    }

    @IsTest
    static void scheduledSendsRequireSelectionAndClearSchedule() {
        Integer threwCount = 0;
        Test.startTest();
        try {
            BWM_WaCampCtrlA.sendLeadWhatsAppScheduled(new List<Id>(), 'tmpl', SCHEDULE);
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        try {
            BWM_WaCampCtrlA.sendOpportunityWhatsAppScheduled(new List<Id>(), 'tmpl', SCHEDULE);
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        try {
            BWM_WaCampCtrlA.sendAccountWhatsAppScheduled(new List<Id>(), 'tmpl', SCHEDULE);
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        try {
            BWM_WaCampCtrlA.sendContactWhatsAppScheduled(new List<Id>(), 'tmpl', SCHEDULE);
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        try {
            BWM_WaCampCtrlA.sendOfflineCampaignWhatsAppScheduled(new List<Id>(), 'tmpl', SCHEDULE);
        } catch (AuraHandledException ex) {
            threwCount++;
        }
        Test.stopTest();

        System.assertEquals(5, threwCount, 'Each scheduled send needs at least one record.');
        System.assertEquals(
            null,
            BWM_CampaignScheduleContext.scheduledDateTime,
            'Schedule must be cleared after the send.'
        );
    }

    @IsTest
    static void scheduleContextSetAndClear() {
        BWM_CampaignScheduleContext.setScheduledDateTime(SCHEDULE);
        System.assertEquals(SCHEDULE, BWM_CampaignScheduleContext.scheduledDateTime);

        BWM_CampaignScheduleContext.clear();
        System.assertEquals(null, BWM_CampaignScheduleContext.scheduledDateTime);
    }
}