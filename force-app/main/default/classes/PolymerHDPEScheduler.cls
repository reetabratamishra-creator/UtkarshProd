global class PolymerHDPEScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new PolymerHDPEBatch(), 1); // Batch size = 1 (change if needed)
    }
}
/*

String cronExp = '0 0 17 * * ?'; // Every day at 5:00 PM

System.schedule(
    'Polymer HDPE Daily Job',
    cronExp,
    new PolymerHDPEScheduler()
);

String cronExp9AM = '0 0 9 * * ?';   // Every day at 9:00 AM
String cronExp5PM = '0 0 17 * * ?';  // Every day at 5:00 PM

System.schedule('Polymer HDPE Job - 9AM', cronExp9AM, new PolymerHDPEScheduler());
System.schedule('Polymer HDPE Job - 5PM', cronExp5PM, new PolymerHDPEScheduler());

*/