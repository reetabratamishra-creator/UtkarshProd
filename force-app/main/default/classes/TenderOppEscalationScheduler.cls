global class TenderOppEscalationScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new TenderOppEscalationBatch(), 200);
    }
}