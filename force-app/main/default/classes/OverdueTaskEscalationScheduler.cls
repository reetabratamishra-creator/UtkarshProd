global class OverdueTaskEscalationScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.debug('===== OverdueTaskEscalationScheduler FIRED =====');
        Database.executeBatch(new OverdueTaskEscalationBatch(), 200);
    }
}